CREATE TABLE ETF         AS select ISIN, WKN, Bezeichnung, Anlagegruppe1, Anlageuniversum1, Anlagegruppe2, Anlageuniversum2 from Anlageuniversum where SecurityType="ETF";
CREATE TABLE Stock       AS select ISIN, WKN, Bezeichnung, Anlagegruppe1, Anlageuniversum1, Anlagegruppe2, Anlageuniversum2 from Anlageuniversum where SecurityType="Stock";
CREATE TABLE Derivatives AS select ISIN, WKN, Bezeichnung, Anlagegruppe1, Anlageuniversum1, Anlagegruppe2, Anlageuniversum2 from Anlageuniversum where SecurityType="Derivatives";
CREATE TABLE Wikifolios  AS select ISIN, WKN, Bezeichnung, Anlagegruppe1, Anlageuniversum1, Anlagegruppe2, Anlageuniversum2 from Anlageuniversum where SecurityType="Wikifolios";
