DECLARE @SQL VARCHAR(MAX);
DECLARE @InfoLevel VARCHAR(10);
DECLARE @DatabaseName VARCHAR(50);
DECLARE @FilegroupName VARCHAR(100);

SET @InfoLevel = '*';		--* for everything (or) Database/FileGroup/File
SET @DatabaseName = '*';	--* for everything (or) the Database name 
SET @FilegroupName = '*';   --* for all filegroups (or) specific filegroup name

CREATE TABLE #output( 
			ServerName varchar(128), 
			DBName varchar(128), 
			FileId bigint,
			PhysicalName varchar(260), 
			ReportDate datetime, 
			Name varchar(128), 
			GroupId int,
			FileGroupName varchar(128), 
			Size_MB real, 
			Free_MB real,
			Max_Size_MB real, 
			Free_Of_Max_Size_MB real
		);
		
SET @SQL = 'USE [?]; 
IF ''?'' = REPLACE(''' + @DatabaseName + ''', ''*'', ''?'')
BEGIN
	INSERT #output 
	SELECT CAST(SERVERPROPERTY(''ServerName'') AS varchar(128)) AS ServerName, 
	''?'' AS DBName, 
	f.fileid,
	f.filename AS PhysicalName, 
	CAST(FLOOR(CAST(getdate() AS float)) AS datetime) AS ReportDate, 
	f.Name, 
	f.GroupId,
	g.groupname FileGroupName,  
	CAST (size*8.0/1024.0 AS int) AS Size_MB, 
	CAST((size - FILEPROPERTY(f.name,''SpaceUsed''))*8.0/1024.0 AS int) AS Free_MB,
	CASE WHEN maxsize = -1 THEN -1
		ELSE CAST (maxsize*8.0/1024.0 AS int) 
	END AS Max_Size_MB, 
	CASE WHEN maxsize = -1 THEN -1
		ELSE CAST((maxsize - FILEPROPERTY(f.name,''SpaceUsed''))*8.0/1024.0 AS int) 
	END AS Free_of_Max_Size_MB
	FROM sysfiles f 
	LEFT JOIN sysfilegroups g 
	ON f.groupid = g.groupid
	WHERE COALESCE(g.groupname,''*'') = REPLACE(''' + @FilegroupName + ''', ''*'', COALESCE(g.groupname,''*''))
END;
';
 

exec sp_MSforeachdb @command1= @SQL; 

		
----------------------------------
--Database level totals
----------------------------------
IF COALESCE(@InfoLevel, '*') IN ('*', 'DATABASE') 
BEGIN
	WITH Inst_Totals
	AS
	(
		SELECT 
			SUM(Size_MB) AS Sum_Size_MB_Inst,
			SUM(Free_MB) AS Sum_Free_MB_Inst,
			SUM(Max_Size_MB) AS Sum_Max_Size_MB_Inst,
			SUM(Free_Of_Max_Size_MB) AS Sum_Free_Of_Max_Size_MB_Inst
		FROM #output
		GROUP BY ServerName
	)
	SELECT
		det.ServerName,
		det.DBName,
		'Database' AS ReportLevel,
		ReportDate,
		COUNT(1) File_Count,
		SUM(Size_MB) Size_MB,
		SUM(Free_MB) Free_MB,	
		CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
			ELSE SUM(Max_Size_MB) 
		END AS Max_Size_MB,
		CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
			ELSE SUM(Free_Of_Max_Size_MB) 
		END AS Free_Of_Max_Size_MB,	
		SUM(CASE WHEN Sum_Size_MB_Inst=0 THEN 0 ELSE ROUND(100 * Size_MB / Sum_Size_MB_Inst,2) END) AS Size_PCT_Inst,
		SUM(CASE WHEN Sum_Free_MB_Inst=0 THEN 0 ELSE ROUND(100 * Free_MB / Sum_Free_MB_Inst,2) END) Free_Size_PCT_Inst,
		CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
			ELSE SUM(CASE WHEN Sum_Max_Size_MB_Inst=0 THEN 0 ELSE ROUND(100 * Max_Size_MB / Sum_Max_Size_MB_Inst,2) END) 
		END AS Max_Size_PCT_Inst,
		CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
			ELSE SUM(CASE WHEN Sum_Free_Of_Max_Size_MB_Inst=0 THEN 0 ELSE ROUND(100 * Free_Of_Max_Size_MB / Sum_Free_Of_Max_Size_MB_Inst,2) END) 
		END AS Free_Of_Max_Size_PCT_Inst
	FROM #output det, 
		Inst_Totals inst_tot
	GROUP BY
		det.ServerName,
		det.DBName,
		ReportDate;
END;

----------------------------------
--Database + Filegroup level totals
---------------------------------- 
IF COALESCE(@InfoLevel, '*') IN ('*', 'FILEGROUP') 
BEGIN
	WITH Inst_Totals
	AS
	(
		SELECT 
			SUM(Size_MB) AS Sum_Size_MB_Inst,
			SUM(Free_MB) AS Sum_Free_MB_Inst,
			CASE WHEN SUM(Max_Size_MB) < 0 THEN -1 
				ELSE SUM(Max_Size_MB) 
			END AS Sum_Max_Size_MB_Inst,
			CASE WHEN SUM(Max_Size_MB) < 0 THEN -1 
				ELSE SUM(Free_Of_Max_Size_MB) 
			END AS Sum_Free_Of_Max_Size_MB_Inst
		FROM #output
		GROUP BY ServerName
	),
	DB_Totals
	AS
	(
		SELECT 
			DBName,
			SUM(Size_MB) AS Sum_Size_MB_DB,
			SUM(Free_MB) AS Sum_Free_MB_DB,
			CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
				ELSE SUM(Max_Size_MB) 
			END AS Sum_Max_Size_MB_DB,
			CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
				ELSE SUM(Free_Of_Max_Size_MB) 
			END AS Sum_Free_Of_Max_Size_MB_DB
		FROM #output
		GROUP BY ServerName, DBName
	)
	SELECT
		det.ServerName,
		det.DBName,
		'Database+Filegroup' AS ReportLevel,
		ReportDate,
		Name,
		GroupId,
		FileGroupName,
		SUM(Size_MB) Size_MB,
		SUM(Free_MB) Free_MB,	
		CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
			ELSE SUM(Max_Size_MB) 
		END AS Max_Size_MB,
		CASE WHEN SUM(Max_Size_MB) < 0 THEN -1 
			ELSE SUM(Free_Of_Max_Size_MB) 
		END AS Free_Of_Max_Size_MB,
		--FG Level
		CASE WHEN SUM(Free_MB)=0 THEN 0 ELSE ROUND(100 * SUM(Free_MB) / SUM(Size_MB),2) END AS Free_Size_PCT_FG,
		CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
			ELSE CASE WHEN SUM(Free_Of_Max_Size_MB)=0 THEN 0 ELSE ROUND(100 * SUM(Free_Of_Max_Size_MB) / SUM(Max_Size_MB) ,2) END 
		END AS Free_Of_Max_Size_PCT_FG,
		--DB Level
		SUM(CASE WHEN Sum_Size_MB_DB=0 THEN 0 ELSE ROUND(100 * Size_MB / Sum_Size_MB_DB,2) END) AS Size_PCT_DB,
		SUM(CASE WHEN Sum_Free_MB_DB=0 THEN 0 ELSE ROUND(100 * Free_MB / Sum_Free_MB_DB,2) END) Free_Size_PCT_DB,
		CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
			ELSE SUM(CASE WHEN Sum_Max_Size_MB_DB=0 THEN 0 ELSE ROUND(100 * Max_Size_MB / Sum_Max_Size_MB_DB,2) END) 
		END AS Max_Size_PCT_DB,
		CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
			ELSE SUM(CASE WHEN Sum_Free_Of_Max_Size_MB_DB=0 THEN 0 ELSE ROUND(100 * Free_Of_Max_Size_MB / Sum_Free_Of_Max_Size_MB_DB,2) END) 
		END AS Free_Of_Max_Size_PCT_DB,
		--Instance Level
		SUM(CASE WHEN Sum_Size_MB_Inst=0 THEN 0 ELSE ROUND(100 * Size_MB / Sum_Size_MB_Inst,2) END) AS Size_PCT_Inst,
		SUM(CASE WHEN Sum_Free_MB_Inst=0 THEN 0 ELSE ROUND(100 * Free_MB / Sum_Free_MB_Inst,2) END) Free_Size_PCT_Inst,
		CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
			ELSE SUM(CASE WHEN Sum_Max_Size_MB_Inst=0 THEN 0 ELSE ROUND(100 * Max_Size_MB / Sum_Max_Size_MB_Inst,2) END) 
		END AS Max_Size_PCT_Inst,
		CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
			ELSE SUM(CASE WHEN Sum_Free_Of_Max_Size_MB_Inst=0 THEN 0 ELSE ROUND(100 * Free_Of_Max_Size_MB / Sum_Free_Of_Max_Size_MB_Inst,2) END) 
		END AS Free_Of_Max_Size_PCT_Inst
	FROM #output det, 
		Inst_Totals inst_tot,
		DB_Totals db_tot
	WHERE
		det.DBName = db_tot.DBName
	GROUP BY
		det.ServerName,
		det.DBName,
		ReportDate,
		Name,
		GroupId,
		FileGroupName;
END;

----------------------------------
--Database + Filegroup + File level totals
---------------------------------- 
IF COALESCE(@InfoLevel, '*') IN ('*', 'FILE') 
BEGIN
	WITH Inst_Totals
	AS
	(
		SELECT 
			SUM(Size_MB) AS Sum_Size_MB_Inst,
			SUM(Free_MB) AS Sum_Free_MB_Inst,
			CASE WHEN SUM(Max_Size_MB) < 0 THEN -1 
				ELSE SUM(Max_Size_MB) 
			END AS Sum_Max_Size_MB_Inst,
			CASE WHEN SUM(Max_Size_MB) < 0 THEN -1 
				ELSE SUM(Free_Of_Max_Size_MB) 
			END AS Sum_Free_Of_Max_Size_MB_Inst
		FROM #output
		GROUP BY ServerName
	),
	DB_Totals
	AS
	(
		SELECT 
			DBName,
			SUM(Size_MB) AS Sum_Size_MB_DB,
			SUM(Free_MB) AS Sum_Free_MB_DB,
			CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
				ELSE SUM(Max_Size_MB) 
			END AS Sum_Max_Size_MB_DB,
			CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
				ELSE SUM(Free_Of_Max_Size_MB) 
			END AS Sum_Free_Of_Max_Size_MB_DB
		FROM #output
		GROUP BY ServerName, DBName
	),
	Filegroup_Totals
	AS
	(
		SELECT 
			DBName,
			FileGroupName,
			SUM(Size_MB) AS Sum_Size_MB_FG,
			SUM(Free_MB) AS Sum_Free_MB_FG,
			CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
				ELSE SUM(Max_Size_MB) 
			END AS Sum_Max_Size_MB_FG,
			CASE WHEN SUM(Max_Size_MB) < 0 THEN -1
				ELSE SUM(Free_Of_Max_Size_MB) 
			END AS Sum_Free_Of_Max_Size_MB_FG
		FROM #output
		GROUP BY ServerName, DBName, FileGroupName
	)
	SELECT
		det.ServerName,
		det.DBName,
		'Database+FileGroup+File' AS ReportLevel,
		ReportDate,
		det.Name,
		det.GroupId,
		det.FileGroupName,
		det.FileId AS File_Id,
		PhysicalName,
		Size_MB,
		Free_MB,	
		Max_Size_MB,
		Free_Of_Max_Size_MB,	
		CASE WHEN Sum_Size_MB_FG=0 THEN 0 ELSE ROUND(100 * Size_MB / Sum_Size_MB_FG,2) END AS Size_PCT_FG,
		CASE WHEN Sum_Free_MB_FG=0 THEN 0 ELSE ROUND(100 * Free_MB / Sum_Free_MB_FG,2) END AS Free_Size_PCT_FG,
		CASE WHEN Max_Size_MB < 0 THEN -1
			ELSE CASE WHEN Sum_Max_Size_MB_FG=0 THEN 0 ELSE ROUND(100 * Max_Size_MB / Sum_Max_Size_MB_FG,2) END 
		END AS Max_Size_PCT_FG,
		CASE WHEN Max_Size_MB < 0 THEN -1 
			ELSE CASE WHEN Sum_Free_Of_Max_Size_MB_FG=0 THEN 0 ELSE ROUND(100 * Free_Of_Max_Size_MB / Sum_Free_Of_Max_Size_MB_FG,2) END 
		END AS Free_Of_Max_Size_PCT_FG,
		CASE WHEN Sum_Size_MB_DB=0 THEN 0 ELSE ROUND(100 * Size_MB / Sum_Size_MB_DB,2) END AS Size_PCT_DB,
		CASE WHEN Sum_Free_MB_DB=0 THEN 0 ELSE ROUND(100 * Free_MB / Sum_Free_MB_DB,2) END Free_Size_PCT_DB,				
		CASE WHEN Max_Size_MB < 0 THEN -1
			ELSE CASE WHEN Sum_Max_Size_MB_DB=0 THEN 0 ELSE ROUND(100 * Max_Size_MB / Sum_Max_Size_MB_DB,2) END 
		END AS Max_Size_PCT_DB,
		CASE WHEN Max_Size_MB < 0 THEN -1
			ELSE CASE WHEN Sum_Free_Of_Max_Size_MB_DB=0 THEN 0 ELSE ROUND(100 * Free_Of_Max_Size_MB / Sum_Free_Of_Max_Size_MB_DB,2) END 
		END AS Free_Of_Max_Size_PCT_DB,
		CASE WHEN Sum_Size_MB_Inst=0 THEN 0 ELSE ROUND(100 * Size_MB / Sum_Size_MB_Inst,2) END AS Size_PCT_Inst,
		CASE WHEN Sum_Free_MB_Inst=0 THEN 0 ELSE ROUND(100 * Free_MB / Sum_Free_MB_Inst,2) END Free_Size_PCT_Inst,
		CASE WHEN Max_Size_MB < 0 THEN -1
			ELSE CASE WHEN Sum_Max_Size_MB_Inst=0 THEN 0 ELSE ROUND(100 * Max_Size_MB / Sum_Max_Size_MB_Inst,2) END 
		END AS Max_Size_PCT_Inst,
		CASE WHEN Max_Size_MB < 0 THEN -1
			ELSE CASE WHEN Sum_Free_Of_Max_Size_MB_Inst=0 THEN 0 ELSE ROUND(100 * Free_Of_Max_Size_MB / Sum_Free_Of_Max_Size_MB_Inst,2) END 
		END AS Free_Of_Max_Size_PCT_Inst
	FROM #output det
		INNER JOIN Inst_Totals inst_tot					
			ON 1=1
		INNER JOIN DB_Totals db_tot	
			ON det.DBName = db_tot.DBName				
		LEFT JOIN Filegroup_Totals fg_tot
			ON det.DBName = fg_tot.DBName
			AND det.FileGroupName = fg_tot.FileGroupName;

END;

DROP TABLE #output;