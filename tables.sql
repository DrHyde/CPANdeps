-- cpandeps database

CREATE TABLE `cpanstats` (
  `id` int(11) NOT NULL,
  `state` varchar(16) DEFAULT NULL,
  `tester` varchar(128) DEFAULT NULL,
  `dist` varchar(128) DEFAULT NULL,
  `version` varchar(32) DEFAULT NULL,
  `perl` varchar(32) DEFAULT NULL,
  `is_dev_perl` tinyint(4) DEFAULT '0',
  `os` varchar(64) DEFAULT NULL,
  `platform` varchar(32) DEFAULT NULL,
  `origosname` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `perlidx` (`perl`),
  KEY `isdevperlidx` (`is_dev_perl`),
  KEY `osidx` (`os`),
  KEY `distversionidx` (`dist`,`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `packages` (
  `module` varchar(128) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `version` varchar(32) DEFAULT NULL,
  `file` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`module`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- cpantesters database

CREATE TABLE `cpanstats` (
  `id` int(11) NOT NULL,
  `guid` varchar(32) DEFAULT NULL,
  `state` varchar(16) DEFAULT NULL,
  `dist` varchar(128) DEFAULT NULL,
  `version` varchar(32) DEFAULT NULL,
  `perl` varchar(32) DEFAULT NULL,
  `platform` varchar(32) DEFAULT NULL,
  `osname` varchar(64) DEFAULT NULL,
  `osvers` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
