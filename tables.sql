CREATE TABLE cpanstats (
  id INT NOT NULL PRIMARY KEY,
  state VARCHAR(16),
  tester VARCHAR(128),
  dist VARCHAR(128),
  version VARCHAR(32),
  perl VARCHAR(32),
  is_dev_perl TINYINT DEFAULT 0,
  os VARCHAR(64),
  platform VARCHAR(32),
  origosname VARCHAR(32)
  -- date INT,              -- not used yet
  -- osvers VARCHAR(16),    -- not used yet
  -- arch(VARCHAR(64)       -- not used yet
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE INDEX perlidx ON cpanstats (perl);
CREATE INDEX isdevperlidx ON cpanstats (is_dev_perl);
CREATE INDEX osidx ON cpanstats (os);
CREATE INDEX distversionidx ON cpanstats (dist, version);

CREATE TABLE packages (
  module VARCHAR(128) BINARY NOT NULL PRIMARY KEY,
  version VARCHAR(32),
  file VARCHAR(256)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

