USE [TavanaR2]
GO
/****** Object:  StoredProcedure [dbo].[RepAccReveiw]    Script Date: 3/15/2022 9:13:01 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER        PROCEDURE [dbo].[RepAccReveiw]
	-- Add the parameters for the stored procedure here
	  @FinancialPeriodIDFrom				SMALLINT				         ,
	  @FinancialPeriodIDTo					SMALLINT			           ,
		@BasedOnLevelOrKindTafsil			TINYINT         = 1      ,--  1= Level  , 2 = Kind
		@MonthFrom  									TINYINT         = NULL   ,--  Only Monthly Kind Report
	  @YearFrom											SMALLINT				= NULL   ,--  Only Monthly Kind Report
	  @MonthTo											TINYINT         = NULL   ,--  Only Monthly Kind Report
	  @YearTo												SMALLINT        = NULL   ,--  Only Monthly Kind Report
    @StartDate										DATETIME			  = NULL   ,
    @TODate												DATETIME			  = NULL   ,
    @TarazKind										TINYINT         = 1 	   ,  --1= Group , 2 = Kol , 3 = Moeen , 4 = Tafsil4 , 5 = Tafsil5,6 = Tafsil6 ,  7 = Tafsil , 8 = ARZ  , 9 = PeyGiri , 10 = CostCenter, 11= TafsilKind
		@TafGRPID											INT							= NULL   ,
    @AccCode											BIGINT	        = NULL   ,
    @AccTafID4										BIGINT          = NULL   ,
    @AccTafID5										BIGINT          = NULL   ,  	
		@AccDocKindList								NVARCHAR(100)	  = NULL   ,
		@AccNatureList								NVARCHAR(100)	  = NULL   ,--SELECT * FROM dbo.AccountNature
		@AccTypeList									NVARCHAR(50)    = NULL   ,--1=permanent 2= Temp , 3 =  Disciplinary Accounts
		@AccDocNoFrom									BIGINT	        = NULL   ,
		@AccDocNoTo										BIGINT	        = NULL   ,
		@SortBy												NVARCHAR(100)	  ='RowNo' ,
		@SortType											NVARCHAR(100)	  ='ASC'   ,
		@NAME													NVARCHAR(200)   = NULL   ,
		@InPeriodDebitRound						BIGINT          = NULL   ,
		@InPeriodCreditRound					BIGINT          = NULL   ,
		@Code													BIGINT          = NULL   ,
		@DebitRemain									BIGINT          = NULL   ,
		@CreditRemain									BIGINT 	        = NULL   ,
    --@DetailView 							    TINYINT         = NULL   ,--1= Group , 2 = Kol , 3 = Moeen , 4=AccTafID4 , 5= AccTafID5 , 6=AccTafID6
		@DetailViewList               NVARCHAR(MAX)   = NULL   ,
	  @PageSize											INT		          = NULL	 ,
    @PageIndex										INT		          = NULL	 ,
    @ColumnName										NVARCHAR(200)   = NULL   ,
    @SortKind											TINYINT         = 1			 , -- 1 = ASC , 2 = DESC
	  @RowIDList										NVARCHAR(500)   = NULL   ,
		@AccDocStateList							NVARCHAR(50)    = NULL   ,
		@TafKindList									NVARCHAR(MAX)   = NULL  

    
AS 
    BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
   SET NOCOUNT ON ;
   --------------------------------------------------------------------------------------
	 /* DetailViewList
   '[ {"OrderNo":"1", "TarazKind":"3","Code":"2500002"  },  {"OrderNo":"2",  "TarazKind":"4","Code":"00001421" } , 
	    { "OrderNo":"3", "TarazKind":"1","Code":"2" }, {"OrderNo":"4",  "TarazKind":"2","Code":"25" }]'

	*/
	  IF @DetailViewList IS NOT NULL
		BEGIN
        DECLARE @DetailList TABLE (OrderNo  TINYINT,TarazKind    TINYINT , Code BIGINT )
				INSERT INTO @DetailList	( TarazKind,  Code)
			
        SELECT  TarazKind,Code
				FROM      OPENJSON(@DetailViewList)
				WITH (TarazKind      TINYINT,   Code    BIGINT) AS D
		 end 
	 --------------------------------------------------------------------------------------
	 IF @SortBy      IS NULL SET @SortBy				= 'RowNO'
   IF @SortType    IS NULL SET @SortType			= 'ASC'
   IF @ColumnName  IS NULL SET @ColumnName		= 'Code'
   IF @SortKind    IS NULL SET @SortKind			= 1 
   IF @PageSize    IS NULL SET @PageSize			= 500
   IF @PageIndex   IS NULL SET @PageIndex			= 1 
   IF @AccTafID4 = 0 SET @AccTafID4						= NULL 
   IF @AccTafID5 = 0 SET @AccTafID5						= NULL 
	 IF @TafKindList = '0' SET @TafKindList = NULL 
   -----------------------------------------------------
	 DECLARE  @StartFinanAllocate   SMALLINT     , @EndFinanAllocate   SMALLINT 
	 ------------------------------------------------------
	 DECLARE  @TafKind TABLE  (TafGRPID  INT ) 
	 -------------------------------------------------------
	 DECLARE @AccType TABLE   (AccType TINYINT)
	 --------------------------------------------------------
	 DECLARE @AccDocState    TABLE (DocStateID        INT ) 
	 --------------------------------------------------------
	 DECLARE 	@AccDocStateList_ALL             BIT = 0 ,
	          @TafKindList_ALL                 BIT = 0 ,
						@AccDocKindList_ALL              BIT = 0 ,
						@AccTypeList_ALL                 BIT = 0 ,
						@TafGRPID_ALL                    BIT = 0
	 ---------------------------------------------------------
	 IF @AccDocStateList      IS NOT NULL SET @AccDocStateList_ALL		 = 1;
	 IF @TafKindList          IS NOT NULL SET @TafKindList_ALL         = 1;
	 IF @AccDocKindList       IS NOT NULL SET @AccDocKindList_ALL      = 1;
	 IF @AccTypeList          IS NOT NULL SET @AccTypeList_ALL         = 1;
	 IF @TafGRPID             IS NOT NULL SET @TafGRPID_ALL            = 1;

	 -----------------------------------------------------------	
			SET @StartFinanAllocate = (SELECT  FinancialAllocateID      FROM dbo.FinancialAllocate  WHERE KolNotBookID      = 1 AND FinancialPeriodID = @FinancialPeriodIDFrom   )												  
			SET @EndFinanAllocate   = (SELECT  FinancialAllocateID      FROM dbo.FinancialAllocate  WHERE KolNotBookID      = 1 AND FinancialPeriodID = @FinancialPeriodIDTo     )												  

	 -----------------------------------------------------
	  IF @AccDocStateList IS NOT NULL 
    BEGIN 
	 	 		INSERT INTO @AccDocState	(DocStateID)
	 	 	  SELECT * FROM Split       (@AccDocStateList,',')
    END
		------------------------------------------------------
   IF @AccDocKindList IS NOT NULL 
    BEGIN 
		DECLARE @Acckind TABLE (AccdocKindCode  INT )
		INSERT INTO @Acckind( AccdocKindCode)
		SELECT * FROM Split (@AccDocKindList,',')
    END 
		---------------------------------------------------------
   IF @AccNatureList IS NOT NULL 
    BEGIN 
		DECLARE @AccNature TABLE (AccNature  INT )
	     INSERT INTO @AccNature( AccNature)
		   SELECT *    FROM Split (@AccNatureList,',')
    END 
		-------------------------------------------------------
    DECLARE @RowList TABLE (RID   SMALLINT )
	  IF          @RowIDList IS NOT NULL 
	  INSERT INTO @RowList( RID)
	  SELECT * FROM  dbo.Split(@RowIDList,',')
		---------------------------------------------------------
	  	IF @TafKindList IS NOT NULL 
			BEGIN 
			    INSERT INTO @TafKind  (TafGRPID )
			    SELECT * FROM dbo.Split(@TafKindList,',')
			END 
		--------------------------------------------------------
		IF @AccTypeList_ALL = 1
		BEGIN 
		    INSERT INTO @AccType  ( AccType )
		    SELECT * FROM dbo.Split(@AccTypeList,',')
		END 
		---------------------------------------------------------
		IF 	@MonthFrom   IS NOT NULL AND  @YearFrom   IS NOT NULL AND  @MonthTo IS NOT NULL  AND
	      @YearTo      IS NOT NULL 
	  BEGIN 
		    EXEC dbo.DateInterval
						                    @YearFrom                 ,--@YearFrom = 0,                -- int
			   	                      @MonthFrom                ,--@MonthFrom = 0,               -- int
			   	                      @YearTo                   ,--@YearTo = 0,                  -- int
			   	                      @MonthTo                  ,--@MonthTo = 0,                 -- int
			   	                      @StartDate    OUTPUT      ,--@DateFrom = @DateFrom OUTPUT, -- date
			   	                      @ToDate       OUTPUT       --@DateTo = @DateTo OUTPUT      -- date
				--SELECT @StartDate , @TODate  --**==	
		END 
		IF @StartDate < (SELECT FinancialAllocateStartDate FROM dbo.FinancialAllocate  
													WHERE  FinancialAllocateID = @StartFinanAllocate
													)
				OR 
				@StartDate > (SELECT FinancialAllocateEndDate FROM dbo.FinancialAllocate  
													WHERE FinancialAllocateID = @EndFinanAllocate
												)
			BEGIN 
					RAISERROR (' شروع  ماه و سال ها در محدوده دوره مالي وارده نيست ',18,1)
			END 
			   	---------------------------------------------------------------------------------------- 
			IF @ToDate < (SELECT FinancialAllocateStartDate FROM dbo.FinancialAllocate  
										WHERE  FinancialAllocateID = @StartFinanAllocate
										)
 					OR 
					@ToDate > (SELECT FinancialAllocateEndDate FROM dbo.FinancialAllocate  
											WHERE FinancialAllocateID = @EndFinanAllocate
										)
			BEGIN 
					RAISERROR ('  پايان ماه و سال ها در محدوده دوره مالي وارده نيست ',18,1)
			END

		 
		---------------------------------------------------------
     	CREATE TABLE #CodingList     
		                           (RowNo																					INT													,
                               	AccMTMapID																		BIGINT											,
																GroupCode																			BIGINT											,
																KolCode																				BIGINT											,
																MoeenCode																			BIGINT											,
																GroupName																			NVARCHAR(100)								,
																KolName																				NVARCHAR(100)								,
																MoeenName																			NVARCHAR(100)								,
																AccTafID4																			BIGINT											,
																AccTafID5																			BIGINT											,
																AccTafID6																			BIGINT											,
																AccTafsilName4																NVARCHAR(100)								,
																AccTafsilName5																NVARCHAR(100)								,
																AccTafsilName6																NVARCHAR(100)								,
																TafGRPID4																		  INT                         ,      
																TafGRPID5																		  INT                         ,      
																TafGRPID6																		  INT                         ,      
																TafGRPName4																		NVARCHAR(100)               ,      
																TafGRPName5																		NVARCHAR(100)               ,      
																TafGRPName6																		NVARCHAR(100)               ,     
																DebitCreditFlag                               BIT													,
																DebitCirculation															DECIMAL(26,6)DEFAULT 0      ,
																CreditCirculation							                DECIMAL(26,6)DEFAULT 0      ,
																RemainAmount                                  DECIMAL(26,6)DEFAULT 0      ,
																DebitRemainAmount 						                DECIMAL(26,6)DEFAULT 0      ,
																CreditRemainAmount 						                DECIMAL(26,6)DEFAULT 0       
															)
		
		  ---------------------------------------------------------------
			INSERT INTO #CodingList
				 	   (  RowNo    , AccMTMapID, DebitCirculation, CreditCirculation,  DebitRemainAmount , CreditRemainAmount   )
					
			 SELECT    ROW_NUMBER() OVER (ORDER BY AccMTMapID  ) RowNo , 
					       T11.AccMTMapID , SUM(T11.DebitAmount) DebitAmount , SUM(T11.CreditAmount) CreditAmount ,
								 CASE WHEN  ISNULL(SUM(T11.DebitAmount),0) - ISNULL(SUM(T11.CreditAmount),0) > 0 THEN  ISNULL(SUM(T11.DebitAmount),0) - ISNULL(SUM(T11.CreditAmount),0)
								 ELSE 0 END ,
								 CASE WHEN ISNULL(SUM(T11.CreditAmount),0) - ISNULL(SUM(T11.DebitAmount),0)  > 0 THEN  ISNULL(SUM(T11.CreditAmount),0) - ISNULL(SUM(T11.DebitAmount),0)
								 ELSE 0 END 
			 FROM (
							 SELECT T12.AccMTMapID , CASE WHEN T12.DebitCreditFlag = 1 THEN AccDocDtlAmount ELSE 0  END  DebitAmount 
																									 , CASE WHEN T12.DebitCreditFlag = 0 THEN AccDocDtlAmount ELSE 0  END  CreditAmount 
							 FROM (
											SELECT AccDocDetail.AccMTMapID , ISNULL(SUM(AccDocDetail.AccDocDtlAmount),0)  AccDocDtlAmount , AccDocDetail.DebitCreditFlag
										  FROM   dbo.AccDoc
														INNER JOIN  dbo.AccDocDetail    ON AccDocDetail.AccDocID    = AccDoc.AccDocId
														INNER JOIN  dbo.VWAccMTList     ON VWAccMTList.AccMTMapID   = AccDocDetail.AccMTMapID
																																				
											WHERE  AccDocState <>0 
											      AND 
														   (@AccDocKindList_ALL      = 0   OR (AccDocKindCode              IN (SELECT AccdocKindCode FROM @Acckind )))
														AND 
														   CAST(dbo.AccDoc.AccDocDate AS DATE) BETWEEN CAST(@startDate AS DATE) AND  CAST(@ToDate AS DATE)
													  AND 
				                       ((AccDocNo >=  @AccDocNoFrom  AND @AccDocNoFrom  IS NOT NULL AND @AccDocNoFrom<>0)
							                  OR @AccDocNoFrom IS NULL OR @AccDocNoFrom = 0 
				                       )
			                      AND
				                       ((AccDocNo <=  @AccDocNoTo  AND @AccDocNoTo  IS NOT NULL AND @AccDocNoTo<>0)
							                   OR @AccDocNoTo IS NULL OR @AccDocNoTo = 0 
				                       )  	   
													  AND
													    ((dbo.AccDoc.AccDocKindCode IN (SELECT AccdocKindCode FROM @Acckind) AND (SELECT COUNT(*) FROM @Acckind) > 0)
						                   OR @AccDocKindList IS NULL 
					                    )
													  AND 
														   (@AccTypeList_ALL  =0 OR (AccType IN  (SELECT AccType  FROM @AccType) )) 
													  AND 
														   (@AccDocStateList_ALL     = 0   OR (AccDoc.AccDocState		      IN (SELECT DocStateID     FROM @AccDocState )))
														AND 
														   ( (@TarazKind = 7 AND AccTafID4 IS NOT NULL )
															   OR 
																 (@TarazKind = 11 AND ISNULL(@TafGRPID ,0)  IN (SELECT TafGRPID FROM dbo.AccTafsilGroup )
																  AND (AccTafID4  IN (SELECT AccTafID   FROM dbo.AccTafsil WHERE TafGRPID = @TafGRPID)
																	     OR 
																			 AccTafID5  IN (SELECT AccTafID   FROM dbo.AccTafsil WHERE TafGRPID = @TafGRPID)
																			 OR 
																			 AccTafID6  IN (SELECT AccTafID   FROM dbo.AccTafsil WHERE TafGRPID = @TafGRPID)
																	    )
															   )
																 OR @TafGRPID IS NULL OR @TarazKind NOT IN (7,11)
															 )
														
														AND 
														   ( @TafKindList_ALL     = 0   
															   OR 
																 (AccTafID4		    IN (SELECT  AccTafID FROM dbo.AccTafsil WHERE TafGRPID IN (SELECT TafGRPID FROM @TafKind) )
																   AND @TarazKind NOT IN (5,6)
																 )
																 OR 
																 (AccTafID5		    IN (SELECT  AccTafID FROM dbo.AccTafsil WHERE TafGRPID IN (SELECT TafGRPID FROM @TafKind) )
																  AND @TarazKind NOT IN (4,6)
																 )
																 OR 
																 (AccTafID6		    IN (SELECT  AccTafID FROM dbo.AccTafsil WHERE TafGRPID IN (SELECT TafGRPID FROM @TafKind) )
																   AND @TarazKind NOT IN (4,5)
																 )
														  )
										   GROUP BY AccDocDetail.AccMTMapID,AccDocDetail.DebitCreditFlag
									 )T12
						)T11
						GROUP BY T11.AccMTMapID		
			------------------------------------------------------------------------------------------
			UPDATE #CodingList 
			SET GroupCode      = GC     , GroupName  = GN     , KolCode         = KC     , KolName   = KN ,MoeenCode = MC         ,MoeenName = MN ,AccTafID4 = AT4 ,
			    AccTafsilName4 = ATN4   , AccTafID5  = AT5    , AccTafsilName5  = ATN5   , AccTafID6 = AT6,AccTafsilName6  = ATN6 ,
					TafGRPID4      = TA.TG4 , TafGRPID5  = TA.TG5 , TafGRPID6       = TA.TG6 ,TafGRPName4 = TGN4,TafGRPName5 = TGN5 , TafGRPName6 = TGN6
			FROM 
			    (
					 SELECT AccMTMapID    , GroupCode GC        , GroupName GN , KolCode KC           , KolName    KN  ,MoeenCode       MC , MoeenName MN,
					        AccTafID4 AT4 , AccTafsilName4 ATN4 , AccTafID5 AT5, AccTafsilName5  ATN5 , AccTafID6  AT6 , AccTafsilName6 ATN6,
									TafGRPID4 TG4 , TafGRPID5      TG5  , TafGRPID6 TG6,
									TafGRPName4 TGN4,TafGRPName5  TGN5, TafGRPName6 TGN6
					 FROM dbo.VWAccMTList
					)TA
			WHERE TA.AccMTMapID = #CodingList.AccMTMapID 

		--	SELECT * FROM #CodingList --**==
-----==============================================================================================-----
		DECLARE @AccTafName NVARCHAR(200)
    DECLARE @R SMALLINT         
    CREATE TABLE #TestTaraz 
               (RowNo						      INT				  , [NAME]				          NVARCHAR(500)	,
                BeforeDebitRound			BIGINT			, BeforeCreditRound			  BIGINT			,
                InPeriodDebitRound		BIGINT			, InPeriodCreditRound			BIGINT			,
                Code						      BIGINT			, DebitRemain					    MONEY			,
                CreditRemain				  MONEY			  , AccRound					      MONEY			,
                DocFlag						BIT DEFAULT 0   , AccTafID					      BIGINT			,
								AccTafID5					    BIGINT			,	AccTafID6					      BIGINT			,
   							AccDocDate					  DATETIME    ,	AccCode		              BIGINT 
               )
               DECLARE @TCount BIGINT,            @Temp   BIGINT 
 
 --IF @ColumnCount 
 
   IF @DetailViewList IS NULL -- @DetailView IS NULL 
   BEGIN 
    IF @TarazKind IN ( 7,11)
     BEGIN --SELECT * FROM dbo.VWAccMTList
					INSERT INTO #TestTaraz
										( RowNo ,[NAME] ,  InPeriodDebitRound , InPeriodCreditRound , Code , DebitRemain , CreditRemain  )  
		   		SELECT   ROW_NUMBER() OVER ( ORDER BY  T.AccTafID   ) AS RowNo , T.AccTafsilName ,
	                 SUM(T.Debitcirculation) InPeriodDebitRound , SUM(T.CreditCirculation) InPeriodCreditRound,
			             T.AccTafID ,
									 ISNULL(SUM(T.Debitcirculation), 0)  - ISNULL(SUM(T.CreditCirculation), 0) AS DebitRemain,
                   ISNULL(SUM(T.CreditCirculation), 0) - ISNULL(SUM(T.Debitcirculation) , 0) AS CreditRemain 
	        FROM (
	                SELECT  AccTafID4 AccTafID , AccTafsilName4 AccTafsilName ,SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
								  FROM    #CodingList
		              WHERE   AccTafID4 IS NOT NULL  	       	   
								  GROUP BY AccTafID4,AccTafsilName4
									
									UNION ALL 

									SELECT   AccTafID5 AccTafID,AccTafsilName5 AccTafsilName, SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
								  FROM     #CodingList
		              WHERE    AccTafID4 IS NOT NULL AND  AccTafID5 IS NOT NULL  	       	   
								  GROUP BY AccTafID5,AccTafsilName5

									UNION ALL 

									SELECT   AccTafID6 AccTafID,AccTafsilName6 AccTafsilName ,SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
								  FROM     #CodingList
		              WHERE    AccTafID4 IS NOT NULL AND  AccTafID5 IS NOT NULL AND  	 AccTafID6 IS NOT NULL  	       	   
								  GROUP BY AccTafID6,AccTafsilName6
				       )T  
		       GROUP BY T.AccTafID,T.AccTafsilName

	        UPDATE #TestTaraz SET DebitRemain = 0  WHERE DebitRemain < 0                                    
          UPDATE #TestTaraz SET CreditRemain = 0 WHERE CreditRemain < 0 
	 
     END --Tafsil  Or TafsilKind
		 ------------------------==================================================================
			 IF @TarazKind = 5
			 BEGIN 
						INSERT INTO #TestTaraz
											( RowNo ,[NAME] ,  InPeriodDebitRound , InPeriodCreditRound , Code , DebitRemain , CreditRemain  )  
		   			SELECT   ROW_NUMBER() OVER ( ORDER BY  T.AccTafID   ) AS RowNo , T.AccTafsilName ,
										 SUM(T.Debitcirculation) InPeriodDebitRound , SUM(T.CreditCirculation) InPeriodCreditRound,
										 T.AccTafID ,
										 ISNULL(SUM(T.Debitcirculation) , 0)  - ISNULL(SUM(T.CreditCirculation), 0) AS DebitRemain,
										 ISNULL(SUM(T.CreditCirculation), 0)  - ISNULL(SUM(T.Debitcirculation) , 0) AS CreditRemain 
						FROM (
					      		SELECT   AccTafID5 AccTafID,AccTafsilName5 AccTafsilName, SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
										FROM     #CodingList
										WHERE    AccTafID5 IS NOT NULL  	       	   
										GROUP BY AccTafID5,AccTafsilName5
								)T  
						 GROUP BY T.AccTafID,T.AccTafsilName

						UPDATE #TestTaraz SET DebitRemain = 0  WHERE DebitRemain < 0                                    
						UPDATE #TestTaraz SET CreditRemain = 0 WHERE CreditRemain < 0 
	 
			 END --  Tafsil6
 ------------------------==================================================================
			 IF @TarazKind = 4
			 BEGIN 
						INSERT INTO #TestTaraz
											( RowNo ,[NAME] ,  InPeriodDebitRound , InPeriodCreditRound , Code , DebitRemain , CreditRemain  )  
		   			SELECT   ROW_NUMBER() OVER ( ORDER BY  T.AccTafID   ) AS RowNo , T.AccTafsilName ,
										 SUM(T.Debitcirculation) InPeriodDebitRound , SUM(T.CreditCirculation) InPeriodCreditRound,
										 T.AccTafID ,
										 ISNULL(SUM(T.Debitcirculation) , 0)  - ISNULL(SUM(T.CreditCirculation), 0) AS DebitRemain,
										 ISNULL(SUM(T.CreditCirculation), 0)  - ISNULL(SUM(T.Debitcirculation) , 0) AS CreditRemain 
						FROM (
										SELECT  AccTafID4 AccTafID , AccTafsilName4 AccTafsilName ,SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
										FROM    #CodingList
										WHERE   AccTafID4 IS NOT NULL  	       	   
										GROUP BY AccTafID4,AccTafsilName4
									
								 )T  
						 GROUP BY T.AccTafID,T.AccTafsilName

						UPDATE #TestTaraz SET DebitRemain = 0  WHERE DebitRemain < 0                                    
						UPDATE #TestTaraz SET CreditRemain = 0 WHERE CreditRemain < 0 
	 
			 END --  Tafsil5 
			 IF @TarazKind = 6
			 BEGIN
						INSERT INTO #TestTaraz
												( RowNo ,[NAME] ,  InPeriodDebitRound , InPeriodCreditRound , Code , DebitRemain , CreditRemain  )  
		   				
						SELECT   ROW_NUMBER() OVER ( ORDER BY  T.AccTafID   ) AS RowNo , T.AccTafsilName ,
										 SUM(T.Debitcirculation) InPeriodDebitRound , SUM(T.CreditCirculation) InPeriodCreditRound,
										 T.AccTafID ,
										 ISNULL(SUM(T.Debitcirculation), 0)  - ISNULL(SUM(T.CreditCirculation), 0) AS DebitRemain,
										 ISNULL(SUM(T.CreditCirculation), 0) - ISNULL(SUM(T.Debitcirculation) , 0) AS CreditRemain 
						FROM (	SELECT   AccTafID6 AccTafID,AccTafsilName6 AccTafsilName ,SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
										FROM     #CodingList
										WHERE    AccTafID6 IS NOT NULL  	       	   
										GROUP BY AccTafID6,AccTafsilName6
								 )T  
						 GROUP BY T.AccTafID,T.AccTafsilName
				--------------------------------------------------------------------------------------------------
				--SELECT * FROM #TestTaraz  --**==
		
				UPDATE #TestTaraz SET DebitRemain = 0  WHERE DebitRemain < 0                                    
				UPDATE #TestTaraz SET CreditRemain = 0 WHERE CreditRemain < 0 
				--SELECT * FROM #TestTaraz  --**==                 
				SET @Temp = 2
						UPDATE  #TestTaraz
						SET     AccRound =  ISNULL(AccRound,0) 
						WHERE RowNo  = 1
        
							--1400-02-28 UPDATE #TestTaraz SET DebitRemain = ISNULL(AccRound,0)WHERE AccRound>=0  /*ISNULL(BeforeDebitRound, 0) + ISNULL(InPeriodDebitRound , 0  )- ISNULL(BeforeCreditRound, 0) -
																																												--ISNULL(InPeriodCreditRound , 0  )*/
							--1400-02-28 UPDATE #TestTaraz SET CreditRemain  =   ISNULL(ABS(AccRound),0)WHERE ISNULL(AccRound,0)<0                                                  
				--SELECT * FROM #TestTaraz  --**==   
				END
    ----=======    
				IF @TarazKind = 3 
				BEGIN
						 INSERT INTO #TestTaraz
									( RowNo ,[NAME] ,  InPeriodDebitRound , InPeriodCreditRound , Code , DebitRemain , CreditRemain  )  
		   				
						 SELECT   ROW_NUMBER() OVER ( ORDER BY  T.MoeenCode   ) AS RowNo , T.MoeenName ,
											SUM(T.Debitcirculation) InPeriodDebitRound , SUM(T.CreditCirculation) InPeriodCreditRound,
											T.MoeenCode ,
											ISNULL(SUM(T.Debitcirculation), 0)  - ISNULL(SUM(T.CreditCirculation), 0) AS DebitRemain,
											ISNULL(SUM(T.CreditCirculation), 0) - ISNULL(SUM(T.Debitcirculation) , 0) AS CreditRemain 
						 FROM (
									SELECT  MoeenCode , MoeenName ,SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
									FROM    #CodingList
									GROUP BY MoeenCode,MoeenName
								)T  
						 GROUP BY T.MoeenCode,T.MoeenName
				----------------------------
									UPDATE #TestTaraz SET DebitRemain = 0  WHERE DebitRemain < 0                                    
									UPDATE #TestTaraz SET CreditRemain = 0 WHERE CreditRemain < 0 
									--SELECT * FROM #TestTaraz --**==
                                            
									-- SET @TCount = (SELECT COUNT(*) FROM #TestTaraz)
						SET @Temp = 2
						 UPDATE  #TestTaraz    SET     AccRound =  ISNULL(AccRound,0)    WHERE RowNo  = 1
						 --UPDATE #TestTaraz SET DebitRemain = ISNULL(AccRound,0)WHERE AccRound>=0  
						 --UPDATE #TestTaraz SET CreditRemain  =   ISNULL(ABS(AccRound),0)WHERE ISNULL(AccRound,0)<0                                          
					END 
				IF @TarazKind = 2
				BEGIN
						INSERT INTO #TestTaraz
							( RowNo ,[NAME] ,  InPeriodDebitRound , InPeriodCreditRound , Code , DebitRemain , CreditRemain  )  
						SELECT   ROW_NUMBER() OVER ( ORDER BY  T.KolCode   ) AS RowNo , T.KolName ,
											SUM(T.Debitcirculation) InPeriodDebitRound , SUM(T.CreditCirculation) InPeriodCreditRound,
											T.KolCode ,
											ISNULL(SUM(T.Debitcirculation), 0)  - ISNULL(SUM(T.CreditCirculation), 0) AS DebitRemain,
											ISNULL(SUM(T.CreditCirculation), 0) - ISNULL(SUM(T.Debitcirculation) , 0) AS CreditRemain 
						FROM (
									SELECT  KolCode , KolName ,SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
									FROM    #CodingList
									GROUP BY KolCode,KolName
								)T  
						GROUP BY T.KolCode,T.KolName  				
					 ------------------------------------------------------------------
						UPDATE #TestTaraz SET DebitRemain = 0  WHERE DebitRemain < 0                                    
						UPDATE #TestTaraz SET CreditRemain = 0 WHERE CreditRemain < 0 
          
                        
							 --ORDER BY dbo.AccGroup.GroupCode,dbo.AccKol.KolCode   
				 END 
				IF @TarazKind = 1
				 BEGIN
				    	INSERT INTO #TestTaraz
							( RowNo ,[NAME] ,  InPeriodDebitRound , InPeriodCreditRound , Code , DebitRemain , CreditRemain  )  
		   				
						 SELECT   ROW_NUMBER() OVER ( ORDER BY  T.GroupCode   ) AS RowNo , T.GroupName ,
											SUM(T.Debitcirculation) InPeriodDebitRound , SUM(T.CreditCirculation) InPeriodCreditRound,
											T.GroupCode ,
											ISNULL(SUM(T.Debitcirculation), 0)  - ISNULL(SUM(T.CreditCirculation), 0) AS DebitRemain,
											ISNULL(SUM(T.CreditCirculation), 0) - ISNULL(SUM(T.Debitcirculation) , 0) AS CreditRemain 
						 FROM (
									 SELECT  GroupCode , GroupName  ,SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
									 FROM    #CodingList
									 GROUP BY GroupCode,GroupName
								 )T  
						 GROUP BY T.GroupCode,T.GroupName
						 ---------------------------------------------------------
						 UPDATE #TestTaraz SET DebitRemain = 0  WHERE DebitRemain < 0                                    
						 UPDATE #TestTaraz SET CreditRemain = 0 WHERE CreditRemain < 0 
				 END
   END -- IF @Detailveiw is null 
	 ------------==========================================================================-----------------------------------------
   IF @DetailViewList IS NOT NULL --@DetailView IS NOT NULL-- AND @DetailView IN (1,2,3,4,5,6)	
   BEGIN
		    DELETE FROM  #TestTaraz 
      --  IF @DetailView = 1
       -- BEGIN --( Groupcode = @AccCode OR VWAccMTList.MoeenCode = @AccCode OR KolCode  = @AccCode OR  ISNULL (@AccCode ,0) = 0 )
					  IF @TarazKind NOT IN ( 7,11)
						BEGIN -- SELECT * FROM #TestTaraz   SELECT *  FROM @DetailList --**==
									INSERT INTO #TestTaraz
					              ( RowNo ,Code,[NAME] ,  InPeriodDebitRound , InPeriodCreditRound ,  DebitRemain , CreditRemain  ,AccCode)  
                 
								  SELECT    T.RowNo , T.Code ,T.CodeName ,
											SUM(T.Debitcirculation) InPeriodDebitRound , SUM(T.CreditCirculation) InPeriodCreditRound,
											
											ISNULL(SUM(T.Debitcirculation) , 0)  - ISNULL(SUM(T.CreditCirculation), 0) AS DebitRemain,
											ISNULL(SUM(T.CreditCirculation), 0)  - ISNULL(SUM(T.Debitcirculation) , 0) AS CreditRemain,
											@AccCode
				         FROM (
									     SELECT 
									       ROW_NUMBER() OVER ( ORDER BY  CASE  WHEN @TarazKind = 1 THEN GROUPcode
																														 WHEN @TarazKind = 2 THEN KolCode 
																														 WHEN @TarazKind = 3 THEN MoeenCode
																														 WHEN @TarazKind = 4 THEN AccTafID4
																														 WHEN @TarazKind = 5 THEN AccTafID5
																														 WHEN @TarazKind = 6 THEN AccTafID6
																														 WHEN @TarazKind = 11 THEN TafGRPID4 
													                                   END    
																						) AS RowNo ,
									        CASE WHEN @TarazKind = 1  THEN GROUPcode
													     WHEN @TarazKind = 2  THEN KolCode 
															 WHEN @TarazKind = 3  THEN MoeenCode
															 WHEN @TarazKind = 4  THEN AccTafID4
															 WHEN @TarazKind = 5  THEN AccTafID5
															 WHEN @TarazKind = 6  THEN AccTafID6
															 WHEN @TarazKind = 11 THEN TafGRPID4 
													END  Code , 
													CASE WHEN @TarazKind = 1 THEN GroupName
													     WHEN @TarazKind = 2 THEN KolName
															 WHEN @TarazKind = 3 THEN MoeenName
															 WHEN @TarazKind = 4 THEN AccTafsilName4
															 WHEN @TarazKind = 5 THEN AccTafsilName5
															 WHEN @TarazKind = 6 THEN AccTafsilName6
															 --WHEN @TarazKind = 11THEN 'tt'
													END CodeName ,
													SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
												
									     FROM    #CodingList
									     WHERE 
													 (GroupCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 1) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 1)= 0)
													 AND 
													 (KolCode   IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 2) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 2)= 0)
													 AND 
													 (MoeenCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 3) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 3)= 0)
													 AND 
													 (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 4) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 4)= 0)
													 AND 
													 (AccTafID5 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 5) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 5)= 0)
													 AND 
													 (AccTafID6 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 6) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 6)= 0)
													 AND 
													 (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 7)= 0
														 OR 
														ISNULL(AccTafID5,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
														 OR 
														ISNULL(AccTafID6,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
													 )
													 AND 
													 (ISNULL(TafGRPID4,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 11)= 0
														 OR 
														ISNULL(TafGRPID5,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
														 OR 
														ISNULL(TafGRPID6,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
													 )
										   GROUP BY 
															CASE WHEN @TarazKind = 1  THEN GROUPcode
																	 WHEN @TarazKind = 2  THEN KolCode 
																	 WHEN @TarazKind = 3  THEN MoeenCode
																	 WHEN @TarazKind = 4  THEN AccTafID4
																	 WHEN @TarazKind = 5  THEN AccTafID5
																	 WHEN @TarazKind = 6  THEN AccTafID6
																	 WHEN @TarazKind = 11 THEN TafGRPID4
															END ,	
														 CASE  WHEN @TarazKind = 1 THEN GroupName
																	 WHEN @TarazKind = 2 THEN KolName
																	 WHEN @TarazKind = 3 THEN MoeenName
																	 WHEN @TarazKind = 4 THEN AccTafsilName4
																	 WHEN @TarazKind = 5 THEN AccTafsilName5
																	 WHEN @TarazKind = 6 THEN AccTafsilName6
																	-- WHEN @TarazKind = 11THEN 'tt'
															END

                      ) T
											WHERE T.Code IS NOT NULL  
								      GROUP BY  T.RowNo , T.Code ,T.CodeName
										--	SELECT * FROM #TestTaraz --**==
						END -- IF @TarazKind Not In (11)
						---------------------------------------------------------------------------
						IF @TarazKind = 7
						BEGIN 
						     INSERT INTO #TestTaraz
					              ( RowNo ,Code,[NAME] ,  InPeriodDebitRound , InPeriodCreditRound ,  DebitRemain , CreditRemain  ,AccCode)  
                 
								 SELECT   ROW_NUMBER() OVER ( ORDER BY  T.AccTafID   ) AS RowNo , T.AccTafID ,T.AccTafsilName ,
												SUM(T.Debitcirculation) InPeriodDebitRound , SUM(T.CreditCirculation) InPeriodCreditRound,
												
												ISNULL(SUM(T.Debitcirculation), 0)  - ISNULL(SUM(T.CreditCirculation), 0) AS DebitRemain,
												ISNULL(SUM(T.CreditCirculation), 0) - ISNULL(SUM(T.Debitcirculation) , 0) AS CreditRemain ,
												@AccCode
							   FROM (
											 SELECT  AccTafID4 AccTafID , AccTafsilName4 AccTafsilName ,SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
											 FROM    #CodingList
											 WHERE   AccTafID4 IS NOT NULL
											      AND   	  
											       (GroupCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 1) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 1)= 0)
													  AND 
													   (KolCode   IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 2) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 2)= 0)
													  AND 
													   (MoeenCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 3) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 3)= 0)
													  AND 
													   (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 4) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 4)= 0)
													  AND 
													   (AccTafID5 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 5) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 5)= 0)
													  AND 
													   (AccTafID6 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 6) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 6)= 0)
													  AND 
													   (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 7)= 0
														  OR 
														  ISNULL(AccTafID5,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
														  OR 
														  ISNULL(AccTafID6,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
													   )
													  AND 
													   (ISNULL(TafGRPID4,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 11)= 0
														  OR 
														  ISNULL(TafGRPID5,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
														  OR 
														  ISNULL(TafGRPID6,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
													   )     	   
											 GROUP BY AccTafID4,AccTafsilName4
									
											UNION ALL 

											SELECT   AccTafID5 AccTafID,AccTafsilName5 AccTafsilName, SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
											FROM     #CodingList
											WHERE    AccTafID4 IS NOT NULL AND  AccTafID5 IS NOT NULL  	
											         AND 
															 (GroupCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 1) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 1)= 0)
															 AND 
															 (KolCode   IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 2) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 2)= 0)
															 AND 
															 (MoeenCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 3) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 3)= 0)
															 AND 
															 (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 4) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 4)= 0)
															 AND 
															 (AccTafID5 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 5) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 5)= 0)
															 AND 
															 (AccTafID6 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 6) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 6)= 0)
															 AND 
															 (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 7)= 0
																 OR 
																ISNULL(AccTafID5,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
																 OR 
																ISNULL(AccTafID6,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
															 )
															 AND 
															 (ISNULL(TafGRPID4,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 11)= 0
																 OR 
																ISNULL(TafGRPID5,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
																 OR 
																ISNULL(TafGRPID6,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
															 )       	   
											GROUP BY AccTafID5,AccTafsilName5

											UNION ALL 

											SELECT   AccTafID6 AccTafID,AccTafsilName6 AccTafsilName ,SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
											FROM     #CodingList
											WHERE    AccTafID4 IS NOT NULL AND  AccTafID5 IS NOT NULL AND  	 AccTafID6 IS NOT NULL  	 
											         AND
															 (GroupCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 1) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 1)= 0)
															 AND 
															 (KolCode   IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 2) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 2)= 0)
															 AND 
															 (MoeenCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 3) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 3)= 0)
															 AND 
															 (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 4) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 4)= 0)
															 AND 
															 (AccTafID5 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 5) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 5)= 0)
															 AND 
															 (AccTafID6 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 6) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 6)= 0)
															 AND 
															 (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 7)= 0
																 OR 
																ISNULL(AccTafID5,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
																 OR 
																ISNULL(AccTafID6,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
															 )
															 AND 
															 (ISNULL(TafGRPID4,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 11)= 0
																 OR 
																ISNULL(TafGRPID5,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
																 OR 
																ISNULL(TafGRPID6,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
															 )      	   
											GROUP BY AccTafID6,AccTafsilName6
										)T  
								GROUP BY T.AccTafID,T.AccTafsilName
								 -----------------------------------------------------------------------------------------------
								/*  SELECT    T.RowNo , T.Code ,T.CodeName ,
											SUM(T.Debitcirculation) InPeriodDebitRound , SUM(T.CreditCirculation) InPeriodCreditRound,
											
											ISNULL(SUM(T.Debitcirculation) , 0)  - ISNULL(SUM(T.CreditCirculation), 0) AS DebitRemain,
											ISNULL(SUM(T.CreditCirculation), 0)  - ISNULL(SUM(T.Debitcirculation) , 0) AS CreditRemain,
											@AccCode
				         FROM (
									     SELECT 
									       ROW_NUMBER() OVER ( ORDER BY  AccTafID4,AccTafID5,AccTafID6) AS RowNo ,
									        CASE WHEN @TarazKind = 1  THEN GROUPcode
													     WHEN @TarazKind = 2  THEN KolCode 
															 WHEN @TarazKind = 3  THEN MoeenCode
															 WHEN @TarazKind = 4  THEN AccTafID4
															 WHEN @TarazKind = 5  THEN AccTafID5
															 WHEN @TarazKind = 6  THEN AccTafID6
															 WHEN @TarazKind = 11 THEN TafGRPID4 
													END  Code , 
													CASE WHEN @TarazKind = 1 THEN GroupName
													     WHEN @TarazKind = 2 THEN KolName
															 WHEN @TarazKind = 3 THEN MoeenName
															 WHEN @TarazKind = 4 THEN AccTafsilName4
															 WHEN @TarazKind = 5 THEN AccTafsilName5
															 WHEN @TarazKind = 6 THEN AccTafsilName6
															 --WHEN @TarazKind = 11THEN 'tt'
													END CodeName ,
													SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
												
									     FROM    #CodingList
									     WHERE 
													 (GroupCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 1) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 1)= 0)
													 AND 
													 (KolCode   IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 2) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 2)= 0)
													 AND 
													 (MoeenCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 3) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 3)= 0)
													 AND 
													 (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 4) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 4)= 0)
													 AND 
													 (AccTafID5 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 5) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 5)= 0)
													 AND 
													 (AccTafID6 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 6) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 6)= 0)
													 AND 
													 (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 7)= 0
														 OR 
														ISNULL(AccTafID5,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
														 OR 
														ISNULL(AccTafID6,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
													 )
													 AND 
													 (ISNULL(TafGRPID4,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 11)= 0
														 OR 
														ISNULL(TafGRPID5,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
														 OR 
														ISNULL(TafGRPID6,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
													 )
										   GROUP BY 
															AccTafID4,AccTafID5,AccTafID6,AccTafsilName4,AccTafsilName5,AccTafsilName6	
														
                      ) T
								      GROUP BY  T.RowNo , T.Code ,T.CodeName
											*/
						END -- if @tarazakind = 7 
						---------------------------------------------------------------------------------------------------
						IF @TarazKind = 11
						BEGIN  
						    INSERT INTO #TestTaraz
					              ( RowNo ,Code,[NAME] ,  InPeriodDebitRound , InPeriodCreditRound ,  DebitRemain , CreditRemain  ,AccCode)  
                 
								 SELECT   ROW_NUMBER() OVER ( ORDER BY  T.TafGRPID   ) AS RowNo , T.TafGRPID ,T.TafGRPName ,
												SUM(T.Debitcirculation) InPeriodDebitRound , SUM(T.CreditCirculation) InPeriodCreditRound,
												
												ISNULL(SUM(T.Debitcirculation), 0)  - ISNULL(SUM(T.CreditCirculation), 0) AS DebitRemain,
												ISNULL(SUM(T.CreditCirculation), 0) - ISNULL(SUM(T.Debitcirculation) , 0) AS CreditRemain ,
												@AccCode
							   FROM (
											 SELECT  TafGRPID4 TafGRPID , TafGRPName4 TafGRPName ,SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
											 FROM    #CodingList
											 WHERE   AccTafID4 IS NOT NULL
											      AND   	  
											       (GroupCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 1) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 1)= 0)
													  AND 
													   (KolCode   IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 2) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 2)= 0)
													  AND 
													   (MoeenCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 3) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 3)= 0)
													  AND 
													   (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 4) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 4)= 0)
													  AND 
													   (AccTafID5 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 5) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 5)= 0)
													  AND 
													   (AccTafID6 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 6) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 6)= 0)
													  AND 
													   (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 7)= 0
														  OR 
														  ISNULL(AccTafID5,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
														  OR 
														  ISNULL(AccTafID6,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
													   )
													  AND 
													   (ISNULL(TafGRPID4,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 11)= 0
														  OR 
														  ISNULL(TafGRPID5,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
														  OR 
														  ISNULL(TafGRPID6,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
													   )     	   
											 GROUP BY  TafGRPID4, TafGRPName4
									
											 UNION ALL 

											 SELECT    TafGRPID5 TafGRPID , TafGRPName5 TafGRPName, SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
											 FROM     #CodingList
											 WHERE    AccTafID4 IS NOT NULL AND  AccTafID5 IS NOT NULL  	
											         AND 
															 (GroupCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 1) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 1)= 0)
															 AND 
															 (KolCode   IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 2) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 2)= 0)
															 AND 
															 (MoeenCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 3) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 3)= 0)
															 AND 
															 (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 4) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 4)= 0)
															 AND 
															 (AccTafID5 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 5) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 5)= 0)
															 AND 
															 (AccTafID6 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 6) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 6)= 0)
															 AND 
															 (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 7)= 0
																 OR 
																ISNULL(AccTafID5,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
																 OR 
																ISNULL(AccTafID6,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
															 )
															 AND 
															 (ISNULL(TafGRPID4,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 11)= 0
																 OR 
																ISNULL(TafGRPID5,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
																 OR 
																ISNULL(TafGRPID6,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
															 )       	   
											 GROUP BY  TafGRPID5  , TafGRPName5 

											 UNION ALL 

											 SELECT    TafGRPID6  , TafGRPName6  ,SUM(DebitCirculation) Debitcirculation , SUM(CreditCirculation) CreditCirculation 
											 FROM     #CodingList
											 WHERE    AccTafID4 IS NOT NULL AND  AccTafID5 IS NOT NULL AND  	 AccTafID6 IS NOT NULL  	 
											         AND
															 (GroupCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 1) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 1)= 0)
															 AND 
															 (KolCode   IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 2) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 2)= 0)
															 AND 
															 (MoeenCode IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 3) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 3)= 0)
															 AND 
															 (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 4) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 4)= 0)
															 AND 
															 (AccTafID5 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 5) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 5)= 0)
															 AND 
															 (AccTafID6 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 6) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 6)= 0)
															 AND 
															 (AccTafID4 IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 7)= 0
																 OR 
																ISNULL(AccTafID5,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
																 OR 
																ISNULL(AccTafID6,0) IN  (SELECT Code   FROM @DetailList WHERE TarazKind = 7)
															 )
															 AND 
															 (ISNULL(TafGRPID4,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) OR (SELECT COUNT(*)  FROM @DetailList WHERE TarazKind = 11)= 0
																 OR 
																ISNULL(TafGRPID5,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
																 OR 
																ISNULL(TafGRPID6,0) IN (SELECT Code   FROM @DetailList WHERE TarazKind = 11) 
															 )      	   
											 GROUP BY TafGRPID6  , TafGRPName6
										)T  
								GROUP BY  TafGRPID  , TafGRPName
						END -- if @TarazKind = 11
			UPDATE #TestTaraz SET DebitRemain = 0  WHERE DebitRemain < 0                                    
      UPDATE #TestTaraz SET CreditRemain = 0 WHERE CreditRemain < 0 
            
                        
                        
                    --ORDER BY dbo.AccGroup.GroupCode,dbo.AccKol.KolCode   
                        
   END

  -- exec('SELECT * FROM #TestTaraz')--' ORDER BY ' + @SortBy + ' ' + @SortType)

  
  --SELECT * FROM #TestTaraz --**==  WHERE --**==  			 		 ( ( CAST(Code AS VARCHAR(50))  LIKE  '%' + CAST(ISNULL(@Code ,'') AS VARCHAR(50)) + '%' ) OR (@Code  IS NULL ))
	/**/
	  UPDATE #TestTaraz SET RowNO = RN 
	  FROM (
	       SELECT --Top(@PageSize * @PageIndex)
		       (
		       CASE @SortKind 
						WHEN 2 THEN (	ROW_NUMBER() OVER  (
																							ORDER  BY  (
																													 CASE     @ColumnName  WHEN  'Code'               THEN  Code 
							           																												 WHEN 'InPeriodDebitRound'  THEN InPeriodDebitRound 
																																								 WHEN 'InPeriodCreditRound' THEN InPeriodCreditRound 
																																								 WHEN 'DebitRemain'         THEN DebitRemain  
																																								 WHEN 'CreditRemain'        THEN CreditRemain 
																													END
																												)DESC,CASE @ColumnName WHEN 'NAME'                THEN [NAME] END DESC 
																						)
												)
					 WHEN  1 THEN (ROW_NUMBER() OVER (
																					 ORDER by (
																											CASE @ColumnName 
																																	WHEN  'Code'                THEN 	  Code
																																	WHEN  'InPeriodDebitRound'  THEN InPeriodDebitRound 
																																	WHEN  'InPeriodCreditRound' THEN InPeriodCreditRound 
																																	WHEN  'DebitRemain'         THEN DebitRemain 
																																	WHEN 'CreditRemain'        THEN CreditRemain 
																											 END 
																											)ASC ,CASE @ColumnName WHEN 'NAME'                THEN [NAME] END ASC 
		                                      ) 

		                 )END 

		   )
		  RN,RowNo FROM #TestTaraz  
	    ) R WHERE R.RowNo = [#TestTaraz].RowNo 

	 

	/**/

  SELECT * 
	FROM  (
	       SELECT TOP (@PageSize * @PageIndex) * 
	       FROM #TestTaraz 
		     WHERE 
							(([NAME] LIKE '%'+@Name +'%' AND @Name IS NOT NULL ) OR ISNULL(@Name,'') = '' )
								AND 
							 ( ( CAST(Code AS VARCHAR(50))  LIKE  '%' + CAST(ISNULL(@Code ,'') AS VARCHAR(50)) + '%' ) OR (@Code  IS NULL ))
									AND 
								 ( ( CAST(InPeriodDebitRound AS NVARCHAR(50))  LIKE  '%' + CAST(ISNULL(@InPeriodDebitRound, '') AS NVARCHAR(50)) + '%' ) OR @InPeriodDebitRound IS NULL)
									AND 
								( ( CAST(InPeriodCreditRound AS NVARCHAR(50)) LIKE  '%' + CAST(ISNULL(@InPeriodCreditRound, '') AS NVARCHAR(50)) + '%') OR @InPeriodCreditRound IS NULL)
									AND 
								( ( Code  LIKE  '%' + CAST(@AccCode AS NVARCHAR(50)) + '%' AND ISNULL(@AccCode,0) <> 0 AND @DetailViewList IS NULL )OR ( ISNULL(@AccCode,0) = 0  OR  @DetailViewList IS NOT  NULL  )  )
								AND 
								( ( Debitremain  LIKE  '%' + CAST(ISNULL(@Debitremain, '') AS NVARCHAR(50)) + '%' ) OR @Debitremain IS NULL )  
									AND 
								( ( CreditRemain  LIKE  '%' + CAST(ISNULL(@CreditRemain, '') AS NVARCHAR(50)) + '%' ) OR ( @CreditRemain IS NULL)  )
		  
		    ORDER  BY RowNo 
	     )	T	WHERE  T.RowNo  >(@PageIndex - 1 ) * @Pagesize
	            AND(( T.RowNo IN (SELECT RID FROM @RowList) AND (SELECT COUNT(*) FROM @RowList)>0) OR @RowIDList IS NULL OR (SELECT COUNT(*) FROM @RowList)=0)
	ORDER  BY T.RowNo 
  
  SELECT SUM(InPeriodDebitRound) TotInPeriodDebitRound , SUM(InPeriodCreditRound) TotInperiodCreditRound ,
         SUM(DebitRemain) TotDebitRemain , SUM(CreditRemain) TotCreditRemain 
  FROM #TestTaraz 
  WHERE
		(([NAME] LIKE '%'+@Name +'%' AND @Name IS NOT NULL ) OR ISNULL(@Name,'') = '' )
		  AND 
		 ( ( CAST(Code AS VARCHAR(50))  LIKE  '%' + CAST(ISNULL(@Code ,'') AS VARCHAR(50)) + '%' ) OR (@Code  IS NULL ))
			  AND 
			 ( ( CAST(InPeriodDebitRound AS NVARCHAR(50))  LIKE  '%' + CAST(ISNULL(@InPeriodDebitRound, '') AS NVARCHAR(50)) + '%' ) OR @InPeriodDebitRound IS NULL)
			  AND 
			( ( CAST(InPeriodCreditRound AS NVARCHAR(50)) LIKE  '%' + CAST(ISNULL(@InPeriodCreditRound, '') AS NVARCHAR(50)) + '%') OR @InPeriodCreditRound IS NULL)
			  AND 
			( ( Code  LIKE  '%' + CAST(@AccCode AS NVARCHAR(50)) + '%' AND ISNULL(@AccCode,0) <> 0 AND @DetailViewlist IS NULL )OR ( ISNULL(@AccCode,0) = 0  OR  @DetailViewList IS NOT  NULL  )  )
		  AND 
			( ( Debitremain  LIKE  '%' + CAST(ISNULL(@Debitremain, '') AS NVARCHAR(50)) + '%' ) OR @Debitremain IS NULL )  
				AND 
			( ( CreditRemain  LIKE  '%' + CAST(ISNULL(@CreditRemain, '') AS NVARCHAR(50)) + '%' ) OR ( @CreditRemain IS NULL)  )
  --===
  SELECT COUNT(*) RowNo    FROM #TestTaraz 
  WHERE 
		(([NAME] LIKE '%'+@Name +'%' AND @Name IS NOT NULL ) OR ISNULL(@Name,'') = '' )
		  AND 
		 ( ( CAST(Code AS VARCHAR(50))  LIKE  '%' + CAST(ISNULL(@Code ,'') AS VARCHAR(50)) + '%' ) OR (@Code  IS NULL ))
			  AND 
			 ( ( CAST(InPeriodDebitRound AS NVARCHAR(50))  LIKE  '%' + CAST(ISNULL(@InPeriodDebitRound, '') AS NVARCHAR(50)) + '%' ) OR @InPeriodDebitRound IS NULL)
			  AND 
			( ( CAST(InPeriodCreditRound AS NVARCHAR(50)) LIKE  '%' + CAST(ISNULL(@InPeriodCreditRound, '') AS NVARCHAR(50)) + '%') OR @InPeriodCreditRound IS NULL)
			  AND 
			( ( Code  LIKE  '%' + CAST(@AccCode AS NVARCHAR(50)) + '%' AND ISNULL(@AccCode,0) <> 0 AND @DetailViewList IS NULL )OR ( ISNULL(@AccCode,0) = 0  OR  @DetailViewList IS NOT  NULL  )  )
		  AND 
			( ( Debitremain  LIKE  '%' + CAST(ISNULL(@Debitremain, '') AS NVARCHAR(50)) + '%' ) OR @Debitremain IS NULL )  
				AND 
			( ( CreditRemain  LIKE  '%' + CAST(ISNULL(@CreditRemain, '') AS NVARCHAR(50)) + '%' ) OR ( @CreditRemain IS NULL)  )
  
--	SELECT * FROM  #TestTaraz
  ---===================
  
   DROP TABLE #TestTaraz 
  END
