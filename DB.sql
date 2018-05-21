-- phpMyAdmin SQL Dump
-- version 4.7.4
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: 2017-11-28 21:51:37
-- 服务器版本： 5.7.20-log
-- PHP Version: 5.6.31

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `nf16`
--

DELIMITER $$
--
-- 存储过程
--
DROP PROCEDURE IF EXISTS `livre_rendre`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `livre_rendre` (IN `tmp_id_u` INT, IN `tmp_id_ouvrage` INT)  BEGIN
		if(select id_p from prete 
			where id_u= tmp_id_u
			and id_o = tmp_id_ouvrage 
            and status != 'rendu' limit 1)
        then
			if( select id_p from prete 
					where id_o = tmp_id_ouvrage
					and id_u= tmp_id_u
					and status = 'retard' limit 1)
				then
					select 'il doit payer le frais de retard';
					if((select count(id_p) from prete p
							where p.status = 'retard'
							and p.id= tmp_id_u) > 1)
					then
						                                                select 'il a encore dautre ouvrage qui est en retard'; 
                  elseif(select id_p from prete p
							where p.status = 'retard'
							and p.id= tmp_id_u
							and p.id_o = tmp_id_ouvrage)
					then
						update usager u set u.status = concat(left(u.status, 1), 0)
							where u.id= tmp_id_u;
					end if;

			end if;
			update ouvrage o set o.nb_s = o.nb_s + 1 
				where o.id_o = tmp_id_ouvrage ; 
			update usager u set u.status = concat(left(u.status, 1) - 1, right(u.status, 1))
				where u.id= tmp_id_u;
			update prete p set p.status = 'rendu' 
				where p.id_o = tmp_id_ouvrage
				and p.id_u= tmp_id_u
                and p.status != 'rendu'
				LIMIT 1;
		else
			select 'Attention, lecteur ne dispose pas cet ouvrage';
		end if;
END$$

DROP PROCEDURE IF EXISTS `prete_ouvrage`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `prete_ouvrage` (IN `tmp_id_u` INT, IN `tmp_id_ouvrage` INT)  BEGIN
	if((select left(u.status, 1) from usager u where u.id = tmp_id_u) = (select c.nbmax_l from categorie c, usager u where u.id = tmp_id_u and c.id_c = u.id_c)) 
        then
			select 'prete echouer parce que le usager dispose deja le maximal douvrages';
    elseif((select right(u.status, 1) from usager u where u.id = tmp_id_u) = 1)
		then
			select 'le status du usager nest pas bon';
	elseif((select o.nb_s from ouvrage o where o.id_o = tmp_id_ouvrage) = 0)
		then
			select 'vous tapez le faux code_ouvrage, dans le BD, le stock est 0';
	else
		INSERT INTO `prete` (`date_debut`, `date_fin`, `id_u`, `id_o`) 
			values (current_date(), DATE_ADD(current_date(), INTERVAL (select c.nbmax_j from categorie c, usager u where u.id = tmp_id_u and c.id_c = u.id_c ) day),
				tmp_id_u, tmp_id_ouvrage);
		update usager u set u.status = concat(left(u.status, 1) + 1, right(u.status, 1)) where u.id = tmp_id_u;
        update ouvrage o set o.nb_s = o.nb_s - 1 where o.id_o = tmp_id_ouvrage;
	end if;

END$$

DROP PROCEDURE IF EXISTS `usager_a_rendre`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `usager_a_rendre` (IN `x` INT)  BEGIN
	select distinct u.*  from usager u, prete p
		where u.id = p.id_u
        and p.status = 'bon'
        and x = datediff(p.date_fin ,curdate());
END$$

--
-- 函数
--
DROP FUNCTION IF EXISTS `reception_ouvrage`$$
CREATE DEFINER=`root`@`localhost` FUNCTION `reception_ouvrage` (`i` INT) RETURNS INT(11) BEGIN
	update suggestion set status = 'acceptfini' where status = 'accept' and id_s = i;
    IF(select o.id_o from ouvrage o, suggestion s 
		where o.isbn = s.isbn 
        and s.id_s = i 
        and s.status = 'acceptfini')
		then 
			update ouvrage o, suggestion s set o.nb_s = o.nb_s + s.nb, o.nb_e = o.nb_e + s.nb 
			where o.isbn = s.isbn 
            and s.id_s = i;
	elseif(select s.isbn from suggestion s 
			where s.id_s = i 
			and s.status = 'acceptfini' 
            and s.isbn not in(select o.isbn from ouvrage o))
			then 
				INSERT INTO `ouvrage` (`id_o`,`isbn`, `auteur`, `titre`,`nb_e`, `nb_s`) 
					(select (count(o.id_o)+1),s.isbn, s.auteur, s.titre,s.nb, s.nb from suggestion s,ouvrage o
					where s.id_s = i);
	end if;
        
RETURN 1;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- 表的结构 `categorie`
--

DROP TABLE IF EXISTS `categorie`;
CREATE TABLE IF NOT EXISTS `categorie` (
  `id_c` tinyint(3) NOT NULL COMMENT 'l''identifiant pour la categorie',
  `nbmax_j` tinyint(3) NOT NULL COMMENT 'nombre jours maximal de prete pour ce groupe',
  `nbmax_l` tinyint(3) NOT NULL COMMENT 'nombre livres maximal de prete pour ce groupe',
  PRIMARY KEY (`id_c`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `categorie`
--

INSERT INTO `categorie` (`id_c`, `nbmax_j`, `nbmax_l`) VALUES
(1, 10, 3),
(2, 15, 5),
(3, 20, 6);

-- --------------------------------------------------------

--
-- 替换视图以便查看 `info_ouvrage`
-- (See below for the actual view)
--
DROP VIEW IF EXISTS `info_ouvrage`;
CREATE TABLE IF NOT EXISTS `info_ouvrage` (
`id_o` int(11)
,`titre` varchar(50)
,`isbn` varchar(30)
,`nb_e` tinyint(3)
,`id` int(11)
,`nom` varchar(12)
,`prenom` varchar(12)
,`date_debut` date
,`date_fin` date
,`status` varchar(10)
);

-- --------------------------------------------------------

--
-- 表的结构 `ouvrage`
--

DROP TABLE IF EXISTS `ouvrage`;
CREATE TABLE IF NOT EXISTS `ouvrage` (
  `id_o` int(11) NOT NULL AUTO_INCREMENT COMMENT 'identifiant des livres',
  `isbn` varchar(30) NOT NULL,
  `auteur` varchar(20) DEFAULT NULL,
  `titre` varchar(50) DEFAULT NULL,
  `nb_e` tinyint(3) NOT NULL DEFAULT '1' COMMENT 'nombre d''exemplaire, par défaut 1',
  `nb_s` tinyint(3) NOT NULL DEFAULT '1' COMMENT 'nombre de stock;  par défaut 1',
  PRIMARY KEY (`id_o`),
  UNIQUE KEY `id_l_UNIQUE` (`id_o`),
  UNIQUE KEY `isbn_UNIQUE` (`isbn`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `ouvrage`
--

INSERT INTO `ouvrage` (`id_o`, `isbn`, `auteur`, `titre`, `nb_e`, `nb_s`) VALUES
(1, '2-86601-633-5', 'Jean-Raphaël', 'AXS, serveur avancé sous UNIX', 2, 0),
(2, '2-7429-2222-9', 'Olekhnovitch', 'Réseaux poste à poste', 6, 6),
(3, '2-225-84666-9', 'Shah, Amit', 'FDDI, réseau haut débit', 4, 2),
(4, '2-7440-0877-X', 'Toth, Viktor T', 'Linux : solution réseau', 1, 0),
(5, '2-7298-8606-0', 'Ecoto,François', 'INITIATION À LA RECHERCHE OPÉRATIONNELLE', 7, 5),
(6, '978-2-7590-1297-8', 'Joncheray,Hélène', 'B.a.-ba du management', 3, 3),
(7, '2-84001-059-3 ', 'Davidow, William H', 'entreprise à l\'âge du virtuel (L\')', 2, 0),
(8, '978-2-7081-3012-8', 'Morin, Pierre', 'manager à l\'écoute du sociologue (Le)', 1, 0),
(9, '2-212-09033-1', 'Balouet, Vincent', 'entreprise  à l\'an 2000 (L\')', 1, 0),
(10, '978-2-200-61752-3', 'Dupuy,Francis', 'Anthropologie économique', 5, 4),
(11, '2-7178-3186-X', 'Bloch, Alain', 'intelligence économique (L\')', 4, 4),
(12, '2-212-09033-2', 'Delannoy, Claude', 'le passage à l\'an 2000 (L\')', 3, 3);

-- --------------------------------------------------------

--
-- 表的结构 `prete`
--

DROP TABLE IF EXISTS `prete`;
CREATE TABLE IF NOT EXISTS `prete` (
  `id_p` int(11) NOT NULL AUTO_INCREMENT COMMENT 'identifiant de prète',
  `date_debut` date DEFAULT NULL COMMENT 'date le prete',
  `date_fin` date DEFAULT NULL COMMENT 'date de rendre',
  `status` varchar(10) DEFAULT 'bon' COMMENT 'signfie l''ouvage est bon ou retarde ou rendu',
  `id_u` int(11) DEFAULT NULL COMMENT 'identifiant de lecteur, clé étranger, faire réréfence à table usager',
  `id_o` int(11) DEFAULT NULL COMMENT 'identifiant de livre, clé étranger, faire réréfence à table ouvrage',
  PRIMARY KEY (`id_p`),
  KEY `id_l_idx` (`id_u`),
  KEY `id_livre_idx` (`id_o`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `prete`
--

INSERT INTO `prete` (`id_p`, `date_debut`, `date_fin`, `status`, `id_u`, `id_o`) VALUES
(3, '2017-11-29', '2017-12-09', 'bon', 3, 4),
(4, '2017-11-29', '2017-11-19', 'retard', 8, 8),
(5, '2017-11-29', '2017-11-19', 'retard', 4, 2),
(6, '2017-11-29', '2017-12-19', 'bon', 4, 3),
(7, '2017-11-29', '2017-12-19', 'bon', 4, 9),
(8, '2017-11-29', '2017-12-19', 'bon', 4, 7),
(9, '2017-11-29', '2017-12-19', 'bon', 4, 7),
(10, '2017-11-29', '2017-12-19', 'bon', 4, 1),
(11, '2017-11-29', '2017-12-19', 'bon', 7, 1),
(12, '2017-11-29', '2017-12-14', 'bon', 5, 5),
(13, '2017-11-29', '2017-12-14', 'bon', 5, 5),
(14, '2017-11-29', '2017-12-09', 'bon', 1, 10),
(15, '2017-11-29', '2017-12-09', 'bon', 2, 3);

-- --------------------------------------------------------

--
-- 表的结构 `suggestion`
--

DROP TABLE IF EXISTS `suggestion`;
CREATE TABLE IF NOT EXISTS `suggestion` (
  `id_s` int(11) NOT NULL AUTO_INCREMENT COMMENT 'identifant de suggestion',
  `auteur` varchar(20) DEFAULT NULL,
  `titre` varchar(30) DEFAULT NULL,
  `isbn` varchar(30) NOT NULL,
  `nb` tinyint(3) DEFAULT '1' COMMENT 'nombre d''exemplaire commandé',
  `status` varchar(10) DEFAULT 'attendre' COMMENT 'signfie que la suggestion est accept, nonaccept, atendre ou acceptfini',
  `id_u` int(11) NOT NULL COMMENT 'identifiant de lecteur qui fait la suggestion',
  PRIMARY KEY (`id_s`),
  KEY `id_l_idx` (`id_u`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `suggestion`
--

INSERT INTO `suggestion` (`id_s`, `auteur`, `titre`, `isbn`, `nb`, `status`, `id_u`) VALUES
(1, 'Davidow, William H.', 'serveur avancé sous UNIX', '2-212-08898-1', 4, 'attendre', 3),
(2, 'Balouet, Vincent', 'RÉSEAUX ATM', '2-212-08898-0', 1, 'attendre', 5),
(3, 'Dupuy, Francis', 'PostScript : l\'essentiel', '2-212-08785-3', 1, 'acceptfini', 6),
(4, 'Ecoto, François', 'Dynamique fluviale', '2-212-08785-6', 1, 'attendre', 2),
(5, 'Olekhnovitch', 'Réseaux poste à poste', '2-7429-2222-9', 1, 'acceptfini', 3),
(6, 'Ecoto, François', 'Concevoir des applications Web', '2-212-09172-9', 2, 'attendre', 3),
(7, 'Davidow, William H.', 'Réussir un projet de site web', '978-2-212-12742-3', 3, 'attendre', 1),
(8, 'Ecoto, François', 'Conduite de projet Web', '2-212-11911-9', 5, 'accept', 5),
(9, 'Davidow, William H.', 'conduite de projet', '2-212-11039-1', 3, 'acceptfini', 4);

-- --------------------------------------------------------

--
-- 表的结构 `usager`
--

DROP TABLE IF EXISTS `usager`;
CREATE TABLE IF NOT EXISTS `usager` (
  `ID` int(11) NOT NULL AUTO_INCREMENT COMMENT 'identifiant pour les usagers',
  `nss` varchar(25) NOT NULL COMMENT 'numéro de sécurité social',
  `id_c` tinyint(3) NOT NULL DEFAULT '1' COMMENT 'initialiser par défaut du valeur1, identifiant de groupe, clé étrangère, faire réference à table ''categorie''''',
  `nom` varchar(12) DEFAULT NULL,
  `prenom` varchar(12) DEFAULT NULL,
  `sex` varchar(2) DEFAULT NULL,
  `email` varchar(30) DEFAULT NULL,
  `status` varchar(2) DEFAULT '00' COMMENT 'un status pour enregistrer des infomations sur le lecteur, deux chiffre comme char, le premier est nombre d''ouvrage que lecteur prète pour, deuxième signfie 0 = bon lecteur, 1 = mauvais lecteur',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `id_UNIQUE` (`ID`),
  UNIQUE KEY `nss_UNIQUE` (`nss`),
  KEY `id_g_idx` (`id_c`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `usager`
--

INSERT INTO `usager` (`ID`, `nss`, `id_c`, `nom`, `prenom`, `sex`, `email`, `status`) VALUES
(1, '123456', 1, 'WANG', 'Gao', 'h', 'WANGGao@utt.fr', '10'),
(2, '654987', 1, 'LIAN', 'Wei', 'h', 'LIANWei@utt.fr', '10'),
(3, '123789', 1, 'cici', 'chiris', 'h', 'cicichiris@utt.fr', '20'),
(4, '456789', 3, 'baba', 'chirs', 'f', 'babachirs@utt.fr', '61'),
(5, '321654', 2, 'mama', 'chirs', 'h', 'mamachirs@utt.fr', '20'),
(6, '987654', 1, 'nunu', 'tommy', 'h', 'nunutommy@utt.fr', '00'),
(7, '789645', 3, 'tutu', 'kenny', 'f', 'tutukenny@utt.fr', '10'),
(8, '654456', 3, 'fang', 'vicky', 'f', 'fangvicky@utt.fr', '11'),
(9, '423234', 3, 'DU', 'Qiaoqian', 'f', 'DUQiaoqian@utt.fr', '00'),
(10, '345765', 2, 'YE', 'Xingyu', 'h', 'YEXingyu@utt.fr', '00');

-- --------------------------------------------------------

--
-- 视图结构 `info_ouvrage`
--
DROP TABLE IF EXISTS `info_ouvrage`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `info_ouvrage`  AS  select `o`.`id_o` AS `id_o`,`o`.`titre` AS `titre`,`o`.`isbn` AS `isbn`,`o`.`nb_e` AS `nb_e`,`u`.`ID` AS `id`,`u`.`nom` AS `nom`,`u`.`prenom` AS `prenom`,`p`.`date_debut` AS `date_debut`,`p`.`date_fin` AS `date_fin`,`p`.`status` AS `status` from ((`ouvrage` `o` join `usager` `u`) join `prete` `p`) where ((`o`.`id_o` = `p`.`id_o`) and (`u`.`ID` = `p`.`id_u`)) order by `o`.`id_o` ;

--
-- 限制导出的表
--

--
-- 限制表 `prete`
--
ALTER TABLE `prete`
  ADD CONSTRAINT `id_ouvrage` FOREIGN KEY (`id_o`) REFERENCES `ouvrage` (`id_o`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  ADD CONSTRAINT `id_usager` FOREIGN KEY (`id_u`) REFERENCES `usager` (`ID`) ON DELETE NO ACTION ON UPDATE NO ACTION;

--
-- 限制表 `suggestion`
--
ALTER TABLE `suggestion`
  ADD CONSTRAINT `id_l` FOREIGN KEY (`id_u`) REFERENCES `usager` (`ID`) ON DELETE NO ACTION ON UPDATE NO ACTION;

--
-- 限制表 `usager`
--
ALTER TABLE `usager`
  ADD CONSTRAINT `id_g` FOREIGN KEY (`id_c`) REFERENCES `categorie` (`id_c`) ON DELETE NO ACTION ON UPDATE NO ACTION;

DELIMITER $$
--
-- 事件
--
DROP EVENT `liste_retard`$$
CREATE DEFINER=`root`@`localhost` EVENT `liste_retard` ON SCHEDULE EVERY 1 DAY STARTS '2017-12-01 19:14:10' ON COMPLETION PRESERVE ENABLE COMMENT 'lister chaque jour des retard' DO update prete p set p.status = 'retard' 
			where p.date_fin < current_date() 
            and p.status = 'bon'$$

DELIMITER ;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
