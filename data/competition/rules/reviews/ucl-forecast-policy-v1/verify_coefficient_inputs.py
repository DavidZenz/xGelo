"""Read-only validation of the proposed official UEFA coefficient transcription."""
import csv, hashlib, json, pathlib
base = pathlib.Path(__file__).resolve().parent
rows = list(csv.DictReader((base/'club_coefficients_2026.csv').open()))
assert len(rows)==36 and len({r['club_id'] for r in rows})==36 and len({r['uefa_club_id'] for r in rows})==36
records={}
for page in range(1,10):
    path=base/'evidence'/f'uefa-coefficients-2026-page{page}.json'
    body=json.loads(path.read_text())
    assert body['data']['lastUpdateDate']=='2026-07-03T14:22:35+0000'
    for index,record in enumerate(body['data']['members'],1):
        uid=record['member']['id'];assert uid not in records
        records[uid]=(record,path,index)
assert len(records)==415
floors={r[0]['overallRanking']['nationalAssociationPoints'] for r in records.values() if r[0]['member']['countryCode']=='ITA'}
assert floors=={19.989}
for row in rows:
    coefficient=float(row['effective_coefficient']);floor=float(row['association_floor']);total=float(row['club_five_season_sum'])
    assert abs(coefficient-max(total,floor))<1e-9
    seasons={year:float(row[f'season_{year}']) for year in range(2022,2027)}
    assert abs(sum(seasons.values())-total)<1e-9
    assert row['reference_first_season_year']=='2022' and row['reference_last_season_year']=='2026'
    if row['uefa_club_id'] in records:
        record,path,index=records[row['uefa_club_id']];overall=record['overallRanking'];member=record['member']
        assert overall['baseSeasonYear']==2022 and overall['targetSeasonYear']==2026
        assert row['uefa_name']==member['displayName'] and row['uefa_official_name']==member['displayOfficialName']
        assert row['uefa_association']==member['countryCode']
        assert abs(total-overall['totalPoints'])<1e-9 and abs(floor-overall['nationalAssociationPoints'])<1e-9 and abs(coefficient-overall['totalValue'])<1e-9
        assert int(row['official_overall_position'])==overall['position']
        official={s['seasonYear']:s['totalValue'] for s in record['seasonRankings']}
        assert all(seasons[y]==official.get(y,0) for y in seasons)
        assert row['source_file']==path.name and int(row['source_row'])==index
        assert row['source_sha256']==hashlib.sha256(path.read_bytes()).hexdigest()
    else:
        assert row['club_id']=='club_fd_7397' and row['uefa_club_id']=='79946' and row['uefa_association']=='ITA'
        assert total==0 and floor==19.989 and not row['official_overall_position']
        proof=json.loads((base/'evidence/uefa-como-debut-evidence.json').read_text())
        assert 'primera participación en una competición europea de clubes.' in json.dumps(proof,ensure_ascii=False)
        profile=(base/'evidence/uefa-como-profile-text.json').read_text()
        assert '79946' in profile and 'Como' in profile
assert len({float(r['effective_coefficient']) for r in rows})==36
print('PASS:36 identities,35 official rows+1 documented first-entry floor,415 complete official records,season sums,window,floors,source hashes and distinct coefficients.')
