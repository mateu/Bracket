-- import_2026_field.sql
-- Deterministic 2026 field load (teams/regions) for bracket_2026
START TRANSACTION;

-- Regions fixed by app-required order: 1 East, 2 South, 3 West, 4 Midwest
-- Two-step rename avoids UNIQUE(name) collisions during swaps
UPDATE region SET name = CONCAT('__tmp_', id);
UPDATE region SET name = 'East' WHERE id = 1;
UPDATE region SET name = 'South' WHERE id = 2;
UPDATE region SET name = 'West' WHERE id = 3;
UPDATE region SET name = 'Midwest' WHERE id = 4;

-- Reset team rows from canonical CSV
UPDATE team SET seed=1, name='Duke', region=1, round_out=7 WHERE id=1;
UPDATE team SET seed=16, name='Siena', region=1, round_out=7 WHERE id=2;
UPDATE team SET seed=8, name='Ohio State', region=1, round_out=7 WHERE id=3;
UPDATE team SET seed=9, name='TCU', region=1, round_out=7 WHERE id=4;
UPDATE team SET seed=5, name='St Johns', region=1, round_out=7 WHERE id=5;
UPDATE team SET seed=12, name='Northern Iowa', region=1, round_out=7 WHERE id=6;
UPDATE team SET seed=4, name='Kansas', region=1, round_out=7 WHERE id=7;
UPDATE team SET seed=13, name='California Baptist', region=1, round_out=7 WHERE id=8;
UPDATE team SET seed=6, name='Louisville', region=1, round_out=7 WHERE id=9;
UPDATE team SET seed=11, name='South Florida', region=1, round_out=7 WHERE id=10;
UPDATE team SET seed=3, name='Michigan State', region=1, round_out=7 WHERE id=11;
UPDATE team SET seed=14, name='North Dakota State', region=1, round_out=7 WHERE id=12;
UPDATE team SET seed=7, name='UCLA', region=1, round_out=7 WHERE id=13;
UPDATE team SET seed=10, name='UCF', region=1, round_out=7 WHERE id=14;
UPDATE team SET seed=2, name='UConn', region=1, round_out=7 WHERE id=15;
UPDATE team SET seed=15, name='Furman', region=1, round_out=7 WHERE id=16;
UPDATE team SET seed=1, name='Florida', region=2, round_out=7 WHERE id=17;
UPDATE team SET seed=16, name='Prairie View/Lehigh', region=2, round_out=7 WHERE id=18;
UPDATE team SET seed=8, name='Clemson', region=2, round_out=7 WHERE id=19;
UPDATE team SET seed=9, name='Iowa', region=2, round_out=7 WHERE id=20;
UPDATE team SET seed=5, name='Vanderbilt', region=2, round_out=7 WHERE id=21;
UPDATE team SET seed=12, name='McNeese', region=2, round_out=7 WHERE id=22;
UPDATE team SET seed=4, name='Nebraska', region=2, round_out=7 WHERE id=23;
UPDATE team SET seed=13, name='Troy', region=2, round_out=7 WHERE id=24;
UPDATE team SET seed=6, name='North Carolina', region=2, round_out=7 WHERE id=25;
UPDATE team SET seed=11, name='VCU', region=2, round_out=7 WHERE id=26;
UPDATE team SET seed=3, name='Illinois', region=2, round_out=7 WHERE id=27;
UPDATE team SET seed=14, name='Pennsylvania', region=2, round_out=7 WHERE id=28;
UPDATE team SET seed=7, name='Saint Marys', region=2, round_out=7 WHERE id=29;
UPDATE team SET seed=10, name='Texas A&M', region=2, round_out=7 WHERE id=30;
UPDATE team SET seed=2, name='Houston', region=2, round_out=7 WHERE id=31;
UPDATE team SET seed=15, name='Idaho', region=2, round_out=7 WHERE id=32;
UPDATE team SET seed=1, name='Arizona', region=3, round_out=7 WHERE id=33;
UPDATE team SET seed=16, name='Long Island University', region=3, round_out=7 WHERE id=34;
UPDATE team SET seed=8, name='Villanova', region=3, round_out=7 WHERE id=35;
UPDATE team SET seed=9, name='Utah State', region=3, round_out=7 WHERE id=36;
UPDATE team SET seed=5, name='Wisconsin', region=3, round_out=7 WHERE id=37;
UPDATE team SET seed=12, name='High Point', region=3, round_out=7 WHERE id=38;
UPDATE team SET seed=4, name='Arkansas', region=3, round_out=7 WHERE id=39;
UPDATE team SET seed=13, name='Hawaii', region=3, round_out=7 WHERE id=40;
UPDATE team SET seed=6, name='BYU', region=3, round_out=7 WHERE id=41;
UPDATE team SET seed=11, name='NC State/Texas', region=3, round_out=7 WHERE id=42;
UPDATE team SET seed=3, name='Gonzaga', region=3, round_out=7 WHERE id=43;
UPDATE team SET seed=14, name='Kennesaw State', region=3, round_out=7 WHERE id=44;
UPDATE team SET seed=7, name='Miami', region=3, round_out=7 WHERE id=45;
UPDATE team SET seed=10, name='Missouri', region=3, round_out=7 WHERE id=46;
UPDATE team SET seed=2, name='Purdue', region=3, round_out=7 WHERE id=47;
UPDATE team SET seed=15, name='Queens', region=3, round_out=7 WHERE id=48;
UPDATE team SET seed=1, name='Michigan', region=4, round_out=7 WHERE id=49;
UPDATE team SET seed=16, name='UMBC/Howard', region=4, round_out=7 WHERE id=50;
UPDATE team SET seed=8, name='Georgia', region=4, round_out=7 WHERE id=51;
UPDATE team SET seed=9, name='Saint Louis', region=4, round_out=7 WHERE id=52;
UPDATE team SET seed=5, name='Texas Tech', region=4, round_out=7 WHERE id=53;
UPDATE team SET seed=12, name='Akron', region=4, round_out=7 WHERE id=54;
UPDATE team SET seed=4, name='Alabama', region=4, round_out=7 WHERE id=55;
UPDATE team SET seed=13, name='Hofstra', region=4, round_out=7 WHERE id=56;
UPDATE team SET seed=6, name='Tennessee', region=4, round_out=7 WHERE id=57;
UPDATE team SET seed=11, name='SMU/Miami (OH)', region=4, round_out=7 WHERE id=58;
UPDATE team SET seed=3, name='Virginia', region=4, round_out=7 WHERE id=59;
UPDATE team SET seed=14, name='Wright State', region=4, round_out=7 WHERE id=60;
UPDATE team SET seed=7, name='Kentucky', region=4, round_out=7 WHERE id=61;
UPDATE team SET seed=10, name='Santa Clara', region=4, round_out=7 WHERE id=62;
UPDATE team SET seed=2, name='Iowa State', region=4, round_out=7 WHERE id=63;
UPDATE team SET seed=15, name='Tennessee State', region=4, round_out=7 WHERE id=64;

-- Ensure clean tournament state
UPDATE game SET winner=NULL, lower_seed=0;
DELETE FROM pick;
DELETE FROM region_score;
COMMIT;
