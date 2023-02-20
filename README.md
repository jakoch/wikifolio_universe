## wikifolio_universe [![Build](https://github.com/jakoch/wikifolio_universe/actions/workflows/build.yml/badge.svg)](https://github.com/jakoch/wikifolio_universe/actions/workflows/build.yml)

#### Das gesamte [wikifolio.com Anlageuniversum](https://help.wikifolio.com/article/102-welche-werte-kann-ich-im-wikifolio-handeln) als SQLite Datenbank: https://jakoch.github.io/wikifolio_universe/

Das folgende Tool konvertiert das wikifolio.com Anlageuniversum von XLSX zu CSV und SQLite: https://github.com/jakoch/wikifolio_universe_converter

### Todo
- [x] Download der Excel-Datei [Investment_Universe.de.xlsx](https://wikifolio.blob.core.windows.net/prod-documents/Investment_Universe.de.xlsx) 
- [x] Konvertierung in eine SQLite Datenbank
- [x] Erstellung einer SQLite Datenbank je SecurityType (Stocks, ETFs, Derivatives, Wikifolios)
- [x] Erstellung von CSVs je SecurityType (Stocks, ETFs, Derivatives, Wikifolios)
- [x] Automatische Veröffentlichung 
  - [x] Github Actions cronjob triggers a "main" branch rebuild daily
  - [x] Build artifacts are pushed to "gh-pages" branch
- [ ] Daily Database Diff
- [ ] RSS Feed
