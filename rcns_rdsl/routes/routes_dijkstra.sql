DROP TABLE IF EXISTS dijnodes,dijpaths; 
CREATE TABLE dijnodes ( 
  nodeID int PRIMARY KEY AUTO_INCREMENT NOT NULL, 
  nodename varchar (20) NOT NULL, 
  cost int NULL, 
  pathID int NULL, 
  calculated tinyint NOT NULL  
); 

CREATE TABLE dijpaths ( 
  pathID int PRIMARY KEY AUTO_INCREMENT, 
  fromNodeID int NOT NULL , 
  toNodeID int NOT NULL , 
  cost int NOT NULL 
); 

/*Here is a stored procedure to populate valid nodes and paths:*/

DROP PROCEDURE IF EXISTS dijAddPath; 
DELIMITER | 
CREATE PROCEDURE dijAddPath(  
  pFromNodeName VARCHAR(20), pToNodeName VARCHAR(20), pCost INT  
) 
BEGIN 
  DECLARE vFromNodeID, vToNodeID, vPathID INT; 
  SET vFromNodeID = ( SELECT NodeID FROM dijnodes WHERE NodeName = pFromNodeName ); 
  IF vFromNodeID IS NULL THEN 
    BEGIN 
      INSERT INTO dijnodes (NodeName,Calculated) VALUES (pFromNodeName,0); 
      SET vFromNodeID = LAST_INSERT_ID(); 
    END; 
  END IF; 
  SET vToNodeID = ( SELECT NodeID FROM dijnodes WHERE NodeName = pToNodeName ); 
  IF vToNodeID IS NULL THEN 
    BEGIN 
      INSERT INTO dijnodes(NodeName, Calculated)  
      VALUES(pToNodeName,0); 
      SET vToNodeID = LAST_INSERT_ID(); 
    END; 
  END IF; 
  SET vPathID = ( SELECT PathID FROM dijpaths  
                  WHERE FromNodeID = vFromNodeID AND ToNodeID = vToNodeID  
                ); 
  IF vPathID IS NULL THEN 
    INSERT INTO dijpaths(FromNodeID,ToNodeID,Cost)  
    VALUES(vFromNodeID,vToNodeID,pCost); 
  ELSE 
    UPDATE dijpaths SET Cost = pCost   
    WHERE FromNodeID = vFromNodeID AND ToNodeID = vToNodeID; 
  END IF; 
END;  
| 
DELIMITER ; 

# Use dijAddpath() to populate the tables:

call dijaddpath( 'a', 'b',  4 );
call dijaddpath( 'a', 'c',  3 );
call dijaddpath( 'a', 'd',  1 ); 
call dijaddpath( 'b', 'a', 74 ); 
call dijaddpath( 'b', 'c',  2 ); 
call dijaddpath( 'b', 'e', 12 ); 
call dijaddpath( 'c', 'b', 12 ); 
call dijaddpath( 'c', 'f', 74 ); 
call dijaddpath( 'c', 'j', 12 ); 
call dijaddpath( 'd', 'e', 32 ); 
call dijaddpath( 'd', 'g', 22 ); 
call dijaddpath( 'e', 'd', 66 ); 
call dijaddpath( 'e', 'f', 76 ); 
call dijaddpath( 'e', 'h', 33 ); 
call dijaddpath( 'f', 'i', 11 ); 
call dijaddpath( 'f', 'j', 21 ); 
call dijaddpath( 'g', 'd', 12 ); 
call dijaddpath( 'g', 'h', 10 ); 
call dijaddpath( 'h', 'g',  2 ); 
call dijaddpath( 'h', 'i', 72 ); 
call dijaddpath( 'i', 'f', 31 ); 
call dijaddpath( 'i', 'j',  7 ); 
call dijaddpath( 'i', 'h', 18 ); 
call dijaddpath( 'j', 'f',  8 ); 

/*
SELECT * FROM dijnodes; 
+--------+----------+------+--------+------------+ 
| nodeID | nodename | cost | pathID | calculated | 
+--------+----------+------+--------+------------+ 
|      1 | a        | NULL |   NULL |          0 | 
|      2 | b        | NULL |   NULL |          0 | 
|      3 | d        | NULL |   NULL |          0 | 
|      4 | c        | NULL |   NULL |          0 | 
|      5 | e        | NULL |   NULL |          0 | 
|      6 | f        | NULL |   NULL |          0 | 
|      7 | j        | NULL |   NULL |          0 | 
|      8 | g        | NULL |   NULL |          0 | 
|      9 | h        | NULL |   NULL |          0 | 
|     10 | i        | NULL |   NULL |          0 | 
+--------+----------+------+--------+------------+ 
SELECT * FROM dijpaths; 
+--------+------------+----------+------+ 
| pathID | fromNodeID | toNodeID | cost | 
+--------+------------+----------+------+ 
|      1 |          1 |        2 |    4 | 
|      2 |          1 |        3 |    1 | 
|      3 |          2 |        1 |   74 | 
|      4 |          2 |        4 |    2 | 
|      5 |          2 |        5 |   12 | 
|      6 |          4 |        2 |   12 | 
|      7 |          4 |        6 |   74 | 
|      8 |          4 |        7 |   12 | 
|      9 |          3 |        5 |   32 | 
|     10 |          3 |        8 |   22 | 
|     11 |          5 |        3 |   66 | 
|     12 |          5 |        6 |   76 | 
|     13 |          5 |        9 |   33 | 
|     14 |          6 |       10 |   11 | 
|     15 |          6 |        7 |   21 | 
|     16 |          8 |        3 |   12 | 
|     17 |          8 |        9 |   10 | 
|     18 |          9 |        8 |    2 | 
|     19 |          9 |       10 |   72 | 
|     20 |         10 |        6 |   31 | 
|     21 |         10 |        7 |    7 | 
|     22 |         10 |        9 |   18 | 
|     23 |          7 |        6 |    8 | 
+--------+------------+----------+------+ 

The stored procedure is a 6-step:
null out path columns in the nodes table
find the nodeIDs referenced by input params
loop through all uncalculated one-step paths, calculating costs in each
if a node remains uncalculated, the graph is invalid, so quit
write the path sequence to a temporary table
query the temp table to show the result
*/
DROP PROCEDURE IF EXISTS dijResolve; 
DELIMITER | 
CREATE PROCEDURE dijResolve( pFromNodeName VARCHAR(20), pToNodeName VARCHAR(20) ) 
BEGIN 
  DECLARE vFromNodeID, vToNodeID, vNodeID, vCost, vPathID INT; 
  DECLARE vFromNodeName, vToNodeName VARCHAR(20); 
  -- null out path info in the nodes table 
  UPDATE dijnodes SET PathID = NULL,Cost = NULL,Calculated = 0; 
  -- find nodeIDs referenced by input params 
  SET vFromNodeID = ( SELECT NodeID FROM dijnodes WHERE NodeName = pFromNodeName ); 
  IF vFromNodeID IS NULL THEN 
    SELECT CONCAT('From node name ', pFromNodeName, ' not found.' );  
  ELSE 
    BEGIN 
      -- start at src node 
      SET vNodeID = vFromNodeID; 
      SET vToNodeID = ( SELECT NodeID FROM dijnodes WHERE NodeName = pToNodeName ); 
      IF vToNodeID IS NULL THEN 
        SELECT CONCAT('From node name ', pToNodeName, ' not found.' ); 
      ELSE 
        BEGIN 
          -- calculate path costs till all are done 
          UPDATE dijnodes SET Cost=0 WHERE NodeID = vFromNodeID; 
          WHILE vNodeID IS NOT NULL DO 
            BEGIN 
              UPDATE  
                dijnodes AS src 
                JOIN dijpaths AS Paths ON Paths.FromNodeID = src.NodeID 
                JOIN dijnodes AS dest ON dest.NodeID = Paths.ToNodeID 
              SET dest.Cost = CASE 
                                WHEN dest.Cost IS NULL THEN src.Cost + Paths.Cost 
                                WHEN src.Cost + Paths.Cost < dest.Cost THEN src.Cost + Paths.Cost 
                                ELSE dest.Cost 
                              END, 
                  dest.PathID = Paths.PathID 
              WHERE  
                src.NodeID = vNodeID 
                AND (dest.Cost IS NULL OR src.Cost + Paths.Cost < dest.Cost) 
                AND dest.Calculated = 0; 
        
              UPDATE dijnodes SET Calculated = 1 WHERE NodeID = vNodeID; 

              SET vNodeID = ( SELECT nodeID FROM dijnodes 
                              WHERE Calculated = 0 AND Cost IS NOT NULL 
                              ORDER BY Cost LIMIT 1 
                            ); 
            END; 
          END WHILE; 
        END; 
      END IF; 
    END; 
  END IF; 
  IF EXISTS( SELECT 1 FROM dijnodes WHERE NodeID = vToNodeID AND Cost IS NULL ) THEN 
    -- problem,  cannot proceed 
    SELECT CONCAT( 'Node ',vNodeID, ' missed.' ); 
  ELSE 
    BEGIN 
      -- write itinerary to Map table 
      DROP TEMPORARY TABLE IF EXISTS Map; 
      CREATE TEMPORARY TABLE Map ( 
        RowID INT PRIMARY KEY AUTO_INCREMENT, 
        FromNodeName VARCHAR(20), 
        ToNodeName VARCHAR(20), 
        Cost INT 
      ) ENGINE=MEMORY; 
      WHILE vFromNodeID <> vToNodeID DO 
        BEGIN 
          SELECT  
            src.NodeName,dest.NodeName,dest.Cost,dest.PathID 
            INTO vFromNodeName, vToNodeName, vCost, vPathID 
          FROM  
            dijnodes AS dest 
            JOIN dijpaths AS Paths ON Paths.PathID = dest.PathID 
            JOIN dijnodes AS src ON src.NodeID = Paths.FromNodeID 
          WHERE dest.NodeID = vToNodeID; 
           
          INSERT INTO Map(FromNodeName,ToNodeName,Cost) VALUES(vFromNodeName,vToNodeName,vCost); 
           
          SET vToNodeID = (SELECT FromNodeID FROM dijpaths WHERE PathID = vPathID); 
        END; 
      END WHILE; 
      SELECT FromNodeName,ToNodeName,Cost FROM Map ORDER BY RowID DESC; 
      DROP TEMPORARY TABLE Map; 
    END; 
  END IF; 
END; 
| 
DELIMITER ; 
CALL dijResolve( 'a','i');
