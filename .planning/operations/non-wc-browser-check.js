async () => {
  const response = await fetch(new URL('payload.json', location.href), {cache: 'no-store'});
  if (!response.ok) throw new Error('Payload HTTP ' + response.status);
  const payload = await response.json();
  const meta = payload.metadata;
  const anchors = [...document.querySelectorAll('a[href^="#"]')];
  const missingAnchors = anchors.map(a => a.getAttribute('href')).filter(h => h.length > 1 &&
    !document.getElementById(decodeURIComponent(h.slice(1))));
  const navigation = [...document.querySelectorAll('nav[aria-label="Competitions"] a')].map(a => ({
    label: a.textContent.trim(), url: a.href, current: a.getAttribute('aria-current')
  }));
  const expectedRoutes = ['nations-league', 'euro-qualifying', 'champions-league'];
  const navChecks = await Promise.all(navigation.map(async link => {
    const response = await fetch(link.url, {cache: 'no-store'});
    return {url: link.url, status: response.status};
  }));
  const explicitResources = [...document.querySelectorAll('script[src],link[rel="stylesheet"][href],img[src]')]
    .map(e => e.src || e.href).filter(u => !u.startsWith('data:'));
  const resourceChecks = await Promise.all([...new Set(explicitResources)].map(async url => {
    try { const response = await fetch(url, {cache: 'no-store'}); return {url, status: response.status}; }
    catch (error) { return {url, error: String(error)}; }
  }));
  const sections = Object.fromEntries(Object.entries(payload.sections).map(([id, section]) =>
    [id, {status: section.status, rows: section.rows.length, reason: section.reason}]));
  const body = document.body.innerText;
  const internalMarkers = body.match(/\b(?:row_sha256|source_artifact_id|parent_sha256|schema_version)\b/g) || [];
  const upcoming = payload.edition_id === 'ucl_2026_27' ? payload.sections.fixtures.rows : [];
  const pastUpcoming = upcoming.filter(row => Date.parse(row['Kickoff (UTC)'] || row.kickoff_utc) <= Date.now()).length;
  const fixtureKickoffsMissing = upcoming.filter(row => !Number.isFinite(Date.parse(row['Kickoff (UTC)'] || row.kickoff_utc))).length;
  return {
    url: location.href, title: document.title, viewport: {width: innerWidth, height: innerHeight},
    pageWidth: document.documentElement.scrollWidth,
    noPageOverflow: document.documentElement.scrollWidth <= innerWidth,
    edition: payload.edition_id, batch: meta.batch_id, forecastStatus: meta.forecast_status,
    lifecycle: meta.lifecycle_state, sourceStatus: meta.source_status,
    sourceAsOf: meta.source_as_of_utc, lastRefresh: meta.last_refresh_at_utc,
    generatedAt: meta.generated_at_utc, simulationCount: meta.simulation_count,
    navigation, navChecks, allExpectedRoutesLinked: expectedRoutes.every(route =>
      navigation.some(link => new URL(link.url).pathname.endsWith('/competitions/' + route + '/'))),
    missingAnchors: [...new Set(missingAnchors)], resourceChecks,
    failedExplicitResources: resourceChecks.filter(r => r.status >= 400),
    unverifiedResources: resourceChecks.filter(r => r.error),
    brokenImages: [...document.images].filter(img => !img.complete || !img.naturalWidth).map(img => img.src),
    visibleInternalMarkers: [...new Set(internalMarkers)],
    clPastUpcoming: pastUpcoming, clMissingKickoffs: fixtureKickoffsMissing,
    clForecastDisabledExplained: payload.edition_id !== 'ucl_2026_27' ||
      (meta.forecast_status === 'unavailable' && /calibration|team.strength/i.test(body)),
    euroPreDrawHonest: payload.edition_id !== 'uefa_euro_2028_qualifying' ||
      (meta.lifecycle_state === 'pre_draw' &&
       Object.entries(payload.sections).filter(([id]) => id !== 'overview').every(([,s]) => s.rows.length === 0)),
    sections
  };
}
