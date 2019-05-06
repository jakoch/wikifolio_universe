## wikifolio_universe [![Build Status](https://travis-ci.org/jakoch/wikifolio_universe.svg?branch=master)](https://travis-ci.org/jakoch/wikifolio_universe)

#### Das gesamte [wikifolio.com Anlageuniversum](https://www.wikifolio.com/de/de/hilfe/tutorials-trader/handel-hinweise/anlageuniversum) als SQLite Datenbank: https://jakoch.github.io/wikifolio_universe/

### Todo
- [x] Download der Excel-Datei [Investment_Universe.de.xlsx](https://wikifolio.blob.core.windows.net/prod-documents/Investment_Universe.de.xlsx) 
- [x] Konvertierung in eine SQLite Datenbank
- [x] Erstellung einer SQLite Datenbank je SecurityType (Stock, ETF, Derivatives, Wikifolio)
- [x] Automatische Veröffentlichung 
  - [x] Travis-CI Cronjob (daily) triggers a "master" branch rebuild 
  - [x] build artifacts are pushed to "gh-pages" branch
- [ ] Daily Database Diff
- [ ] RSS Feed
