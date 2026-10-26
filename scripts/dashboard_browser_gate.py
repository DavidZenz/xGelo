#!/usr/bin/env python3
"""Fail-closed staged dashboard smoke via Safari or explicit Firefox WebDriver.

No third-party runtime, driver installation, or automation preference changes.
The server instruments a served copy (never the staged bytes) before page scripts
run, capturing script errors and unhandled promise rejections.
"""
import argparse
import base64
import functools
import http.server
import json
import pathlib
import signal
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request

INSTRUMENT = b'''<script>window.__dashboardErrors=[];addEventListener('error',e=>window.__dashboardErrors.push(e.message||'script error'));addEventListener('unhandledrejection',e=>window.__dashboardErrors.push(String(e.reason)));</script>'''


class StageHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.path.split('?', 1)[0].endswith('.html'):
            path = pathlib.Path(self.translate_path(self.path))
            if path.is_file():
                content = path.read_bytes().replace(b'<head>', b'<head>' + INSTRUMENT, 1)
                self.send_response(200)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                return
        super().do_GET()


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


class Driver:
    def __init__(self, base):
        self.base = base
        self.session = None

    def call(self, method, path, data=None, session=True):
        prefix = '/session/' + self.session if session and self.session else ''
        body = None if data is None else json.dumps(data).encode()
        request = urllib.request.Request(self.base + prefix + path, body, {'Content-Type': 'application/json'}, method=method)
        try:
            with urllib.request.urlopen(request, timeout=12) as response:
                result = json.load(response)
        except urllib.error.HTTPError as error:
            raise RuntimeError('WebDriver rejected request: ' + error.read().decode()[:1000]) from error
        value = result.get('value')
        if isinstance(value, dict) and value.get('error'):
            raise RuntimeError(value.get('message', value['error']))
        return value

    def js(self, source, *args):
        return self.call('POST', '/execute/sync', {'script': source, 'args': list(args)})

    def element(self, selector):
        result = self.call('POST', '/element', {'using': 'css selector', 'value': selector})
        return result['element-6066-11e4-a52e-4f735466cecf']

    def click(self, selector):
        self.call('POST', '/element/' + self.element(selector) + '/click', {})

    def keys(self, selector, text):
        self.call('POST', '/element/' + self.element(selector) + '/value', {'text': text})


def require(value, message):
    if not value:
        raise RuntimeError(message)


def firefox_viewport(capabilities, width, height):
    # Firefox's outer-window API enforces a desktop minimum width. BiDi changes
    # the real content viewport instead, including CSS media-query evaluation.
    # Node's built-in WebSocket avoids an extra Python package for this opt-in.
    node = shutil.which('node')
    require(node, 'Firefox viewport checks require Node with built-in WebSocket')
    url = capabilities.get('webSocketUrl')
    require(url, 'Firefox did not expose its WebDriver BiDi connection')
    code = '''
const [url,width,height]=process.argv.slice(1);
const ws=new WebSocket(url);
const timer=setTimeout(()=>{console.error('BiDi viewport timeout');process.exit(1)},10000);
ws.onerror=()=>{console.error('BiDi connection failed');process.exit(1)};
ws.onopen=()=>ws.send(JSON.stringify({id:1,method:'browsingContext.getTree',params:{maxDepth:0}}));
ws.onmessage=event=>{
  const message=JSON.parse(event.data);
  if(message.type==='error'){console.error(JSON.stringify(message));process.exit(1)}
  if(message.id===1){
    const contexts=message.result.contexts;
    if(contexts.length!==1){console.error('Expected exactly one test tab');process.exit(1)}
    ws.send(JSON.stringify({id:2,method:'browsingContext.setViewport',params:{context:contexts[0].context,viewport:{width:Number(width),height:Number(height)}}}));
  }else if(message.id===2){clearTimeout(timer);ws.close()}
};'''
    subprocess.run([node, '-e', code, url, str(width), str(height)], check=True,
                   capture_output=True, text=True, timeout=15)


def check_page(driver, route):
    state = driver.js('''return {ready:document.readyState,title:document.querySelector('h1')?.textContent,
      errors:window.__dashboardErrors, width:innerWidth,height:innerHeight,
      overflow:document.documentElement.scrollWidth>innerWidth+1,
      duplicateIds:[...document.querySelectorAll('[id]')].map(e=>e.id).filter((id,i,a)=>a.indexOf(id)!==i),
      unlabeled:[...document.querySelectorAll('input:not([hidden]),select:not([hidden])')].filter(e=>!e.labels?.length&&!e.getAttribute('aria-label')&&!e.getAttribute('aria-labelledby')).map(e=>e.id)}''')
    require(state['ready'] == 'complete' and state['title'], 'Page did not finish loading with a heading')
    require(state['errors'] == [], 'JavaScript errors: ' + str(state['errors']))
    require(not state['overflow'], 'Page-wide horizontal overflow')
    require(not state['duplicateIds'], 'Duplicate control IDs: ' + str(state['duplicateIds']))
    require(not state['unlabeled'], 'Unlabelled form controls: ' + str(state['unlabeled']))
    if route != 'nations-league':
        return state
    state['tab_checks'] = []
    tabs = driver.js("return [...document.querySelectorAll('[data-nl-tab]')].map(e=>e.dataset.nlTab)")
    for tab in tabs:
        driver.click('[data-nl-tab=' + json.dumps(tab) + ']')
        tab_state = driver.js('''return {hash:location.hash,
          visible:[...document.querySelectorAll('[role="tabpanel"]')].filter(e=>!e.hidden).map(e=>e.id),
          overflow:document.documentElement.scrollWidth>innerWidth+1}''')
        require(tab_state['hash'] == '#' + tab and tab_state['visible'] == [tab],
                'Tab visibility/hash failed: ' + tab)
        require(not tab_state['overflow'], 'Page-wide horizontal overflow in tab: ' + tab)
        state['tab_checks'].append({'tab': tab, **tab_state})
    # Real pointer and keyboard events exercise tab handlers, direct hashes,
    # filtering/reset, and selection persistence rather than a static DOM read.
    driver.click('[data-nl-tab="fixtures"]')
    require(driver.js("return location.hash === '#fixtures' && !document.getElementById('fixtures').hidden"), 'Fixtures tab/hash failed')
    before = driver.js("return [...document.querySelectorAll('#fixtures .nl-match-card')].filter(e=>!e.hidden).length")
    driver.keys('#nl-team-search', 'no-such-country-482991')
    require(driver.js("return [...document.querySelectorAll('#fixtures .nl-match-card')].every(e=>e.hidden)"), 'Empty fixture search failed')
    require(driver.js("return /no .*match/i.test(document.getElementById('nl-filter-result-count').textContent)"), 'Empty fixture feedback missing')
    driver.click('#nl-clear-filters')
    require(driver.js("return [...document.querySelectorAll('#fixtures .nl-match-card')].filter(e=>!e.hidden).length") == before, 'Clear filters did not restore fixtures')
    options = driver.js("return [...document.querySelector('#nl-selected-team').options].map(o=>o.value).filter(Boolean)")
    require(options, 'Shared team selector has no teams')
    driver.js("const e=document.querySelector('#nl-selected-team');e.value=arguments[0];e.dispatchEvent(new Event('change',{bubbles:true}));", options[0])
    driver.click('[data-nl-tab="groups"]')
    driver.click('[data-nl-tab="outlook"]')
    require(driver.js("return document.querySelector('#nl-selected-team').value", options[0]) == options[0], 'Selected team was lost across tabs')
    driver.click('[data-nl-tab="groups"]')
    driver.keys('[data-nl-tab="groups"]', '\ue014')  # W3C ArrowRight
    require(driver.js("return document.activeElement.matches('[data-nl-tab]') && document.activeElement.dataset.nlTab !== 'groups'"), 'Keyboard tab navigation failed')
    driver.js("location.hash='results'")
    require(driver.js("return !document.getElementById('results').hidden"), 'Direct results hash failed')
    require(driver.js('return window.__dashboardErrors') == [], 'Interaction raised a JavaScript error')
    driver.click('#nl-clear-team')
    require(driver.js("return document.querySelector('#nl-selected-team').value") == '', 'Clear team failed')
    driver.click('[data-nl-tab="groups"]')
    driver.js('scrollTo(0,0)')
    return state


def run(args):
    stage = pathlib.Path(args.stage_root).resolve(strict=True)
    relative = pathlib.Path(args.path).resolve(strict=True).relative_to(stage)
    route = relative.parts[0]
    handler = functools.partial(StageHandler, directory=str(stage))
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    port = free_port()
    process = subprocess.Popen([args.driver, '--port', str(port)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    driver = Driver('http://127.0.0.1:' + str(port))
    try:
        deadline = time.monotonic() + 10
        while True:
            require(process.poll() is None, 'SafariDriver exited before becoming available')
            try:
                driver.call('GET', '/status', session=False)
                break
            except (OSError, urllib.error.URLError):
                if time.monotonic() >= deadline:
                    raise RuntimeError('SafariDriver did not become available within 10 seconds')
                time.sleep(0.1)
        capabilities = {'browserName': args.browser}
        if args.browser == 'firefox':
            capabilities['moz:firefoxOptions'] = {'args': ['-headless']}
            capabilities['webSocketUrl'] = True
        result = driver.call('POST', '/session', {'capabilities': {'alwaysMatch': capabilities}}, session=False)
        driver.session = result['sessionId']
        actual_browser = result.get('capabilities', {})
        require(actual_browser.get('browserName', '').lower() == args.browser,
                'WebDriver returned a different browser than requested')
        driver.call('POST', '/timeouts', {'script': 10000, 'pageLoad': 20000, 'implicit': 0})
        driver.call('POST', '/url', {'url': 'http://127.0.0.1:' + str(server.server_port) + '/' + relative.as_posix()})
        if args.browser == 'firefox':
            firefox_viewport(actual_browser, args.width, args.height)
        else:
            # WebDriver sizes the outer window; compensate, then VERIFY viewport.
            for _ in range(3):
                viewport = driver.js('return [innerWidth,innerHeight]')
                rect = driver.call('GET', '/window/rect')
                driver.call('POST', '/window/rect', {'width': max(1, rect['width'] + args.width - viewport[0]), 'height': max(1, rect['height'] + args.height - viewport[1])})
        actual = driver.js('return [innerWidth,innerHeight]')
        require(actual == [args.width, args.height], 'Requested viewport unavailable: requested %sx%s; actual %s' % (args.width, args.height, actual))
        evidence = pathlib.Path(args.evidence_dir)
        evidence.mkdir(parents=True, exist_ok=True)
        name = '%s-%sx%s' % (route, args.width, args.height)
        try:
            state = check_page(driver, route)
        finally:
            png = driver.call('GET', '/screenshot')
            (evidence / (name + '.png')).write_bytes(base64.b64decode(png))
        report = {'valid': True, 'route': route, 'browser': actual_browser,
                  'viewport': actual, 'checks': state, 'screenshot': str(evidence / (name + '.png'))}
        (evidence / (name + '.json')).write_text(json.dumps(report, indent=2))
        return report
    finally:
        if driver.session:
            try:
                driver.call('DELETE', '')
            except Exception:
                pass
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        server.shutdown()
        server.server_close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage-root', required=True)
    parser.add_argument('--path', required=True)
    parser.add_argument('--width', type=int, required=True)
    parser.add_argument('--height', type=int, required=True)
    parser.add_argument('--browser', choices=('safari', 'firefox'), default='safari')
    parser.add_argument('--driver', default='/System/Cryptexes/App/usr/bin/safaridriver')
    parser.add_argument('--evidence-dir', default=tempfile.mkdtemp(prefix='xgelo-browser-'))
    args = parser.parse_args()
    def interrupted(signum, _frame):
        raise RuntimeError('Browser gate exceeded its deadline or was interrupted (signal %s)' % signum)
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGALRM, interrupted)
    signal.alarm(75)
    try:
        print(json.dumps(run(args)))
    except Exception as error:
        print(json.dumps({'valid': False, 'failure_reason': str(error)}))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
