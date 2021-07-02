## wikifolio_universe [![Build](https://github.com/jakoch/wikifolio_universe/actions/workflows/build.yml/badge.svg)](https://github.com/jakoch/wikifolio_universe/actions/workflows/build.yml)

#### Das gesamte [wikifolio.com Anlageuniversum](https://www.wikifolio.com/de/de/hilfe/tutorials-trader/handel-hinweise/anlageuniversum) als SQLite Datenbank: https://jakoch.github.io/wikifolio_universe/

### Todo
- [x] Download der Excel-Datei [Investment_Universe.de.xlsx](https://wikifolio.blob.core.windows.net/prod-documents/Investment_Universe.de.xlsx) 
- [x] Konvertierung in eine SQLite Datenbank
- [x] Erstellung einer SQLite Datenbank je SecurityType (Stocks, ETFs, Derivatives, Wikifolios)
- [x] Automatische Veröffentlichung 
  - [x] Github Actions Cronjob triggers a "master" branch rebuild daily
  - [x] build artifacts are pushed to "gh-pages" branch
- [ ] Daily Database Diff
- [ ] RSS Feed
