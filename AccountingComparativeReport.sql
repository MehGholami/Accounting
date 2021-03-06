USE [TavanaR2]
GO
/****** Object:  StoredProcedure [dbo].[RepAccComparative]    Script Date: 3/15/2022 9:12:16 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[RepAccComparative]
	-- Add the parameters for the stored procedure here
	@BranchCodeList                    NVARCHAR(100)  = NULL , -- 4,5,6
	@FinancialPeriodIDFrom             SMALLINT				       ,
	@FinancialPeriodIDTo               SMALLINT			         ,
	@AccAmountDisPlayNature						 TINYINT               ,-- 1 = Remain Kind  , 2 = Debit Circulation Kind  , 3= CreditcirculationKind 
	@AccDocKindList			               NVARCHAR(1000)	= NULL ,
	@AccDocStateList									 NVARCHAR(50)   = NULL ,
	@CurrencyProperty                  TINYINT        = NULL ,-- ويژگي ارزي  
	@CurrencyIDList										 NVARCHAR(100)  = NULL ,
	--------------------============Prioritize Accounts=======================----------------------------
  @AccountsPriorityList              NVARCHAR(300)         ,-- 1 = Group , 2 = Kol  , 3 = Moeen And it is Default , 4 =TafLeve4 , 5 = tafLevel5 , 6 = TafLevel6
  --------------------============Report Settings ==========================----------------------------
	@ReportKind                        TINYINT               , -- 1 = Yearly    , 2 = Monthly  , 3= Periodic
	@PeriodicDate											 NVARCHAR(MAX)  = NULL ,
	@MonthFrom  										   TINYINT        = NULL ,--  Only Monthly Kind Report
	@YearFrom                          SMALLINT				= NULL ,--  Only Monthly Kind Report
	@MonthTo                           TINYINT        = NULL ,--  Only Monthly Kind Report
	@YearTo												     SMALLINT       = NULL ,--  Only Monthly Kind Report
	@ReportNature                      TINYINT               , -- 1=  Simple    , 2 = Analytical       					 
	------------------============= Analytical Options ======================-----------------------------
	@RemainORCirculation               BIT            = 1    ,-- مانده/گردش
	@ConflictOfTwoPeriods              BIT            = NULL ,-- مغايرت دو دوره
	@RatioOfChange                     BIT            = NULL ,-- نسبت تغيير 
	@GrowthRate                        BIT		        = NULL ,-- نرخ رشد 
	---------------==================================================-------------------------------------
	@AggregateViewOfColumns						 BIT            = NULL ,-- نمايش تجميعي ستون ها 
	@AccountsWithoutTafsil             BIT            = NULL ,-- حساب هاي بدون تفصيل 
	@PrintInSeparatePage               BIT            = NULL ,-- چاپ حساب در صفحات مجزا
	---------------==================Secondary Filter================--------------------------------------
--	@PriorityLevel                     TINYINT        = NULL ,-- 4,5,6
	@FilterType                        TINYINT        = NULL ,-- 1 = Tafsil Accounts , 2 = Grouping Tafsil 
	@TafGrpIDList                      NVARCHAR(500)  = NULL , -- '45,6,7,8,454,45'
	@AccountCodeList                   NVARCHAR(MAX)  = NULL -- Json For Account Code List 
	---------------==================================================--------------------------------------
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
 /* @AccountCodeList
   '[ { "AccountsPriorityCode":"3""AccountCodeList":"100014,140025,325001"  },  { "AccountsPriorityCode":"4"	"AccountCodeList":"2530014,3840045,7851012" } ]'
*/
---------------------------------------------------------------------------------------------
 /* @AccountsPriorityList
	 '[ {"RowNo":"1",	"AccKind":"3" },{  "RowNo":"2","AccKind":"4" }]'
	 */
----------------------------------------------------------------------------------------------
	-- @PeriodicDate  JSON 
	/*
	  '[{ "DateFrom":"2020-03-21", "DateTo":"2021-03-21"  } ,{ "DateFrom":"2021-03-21", "DateTo":"2022-03-20"  }]'
	*/
	     
	    	DECLARE    
										@AccDocKindList_ALL              BIT = 0,
										@AccDocStateList_ALL             BIT = 0,
									  @CurrencyProperty_ALL            BIT = 0,
										@CurrencyIDList_ALL              BIT = 0,
										@BranchCodeList_All              BIT = 0
			----------------------------------------------------------
			IF @AccDocKindList       IS NOT NULL SET @AccDocKindList_ALL		 = 1;
			IF @AccDocStateList      IS NOT NULL SET @AccDocStateList_ALL		 = 1;
			IF @CurrencyProperty     IS NOT NULL SET @CurrencyProperty_ALL	 = 1;
			IF @CurrencyIDList       IS NOT NULL SET @CurrencyIDList_ALL		 = 1;
			IF @BranchCodeList       IS NOT NULL SET @BranchCodeList_All     = 1;
										
		-----------------------------------------------------------------------
		 DECLARE @AccDockind     TABLE (AccdocKindCode    INT )
		-----------------------------------------------------
		 DECLARE @AccDocState    TABLE (DocStateID        INT ) 
		 ------------------------------------------------------
		 DECLARE @BranchList     TABLE (BrchCode          INT )
		 -------------------------------------------------------		
		 DECLARE @CurrencyList   TABLE (CurrencyID        INT )	
		 -------------------------------------------------------
		 DECLARE @AccKindList    TABLE ( AccKind   TINYINT , AccKindCodeName   NVARCHAR(50),AccKindName   NVARCHAR(50)) 
		 --------------------------------------------------------				
		 DECLARE @AccPriority    TABLE (RowNo   TINYINT,AccKind   TINYINT,AccKindCodeName   NVARCHAR(50),AccKindName   NVARCHAR(50))
		 ---------------------------------------------------------
		 DECLARE        @P1              TINYINT      , @P2  TINYINT     ,@P3  TINYINT     ,@P4  TINYINT     , @P5  TINYINT     , @P6  TINYINT     ,@DelRow           TINYINT    ,@MaxRow    INT ,
		                @PN1					   NVARCHAR(50) , @PN2 NVARCHAR(50),@PN3 NVARCHAR(50),@PN4 NVARCHAR(50), @PN5 NVARCHAR(50), @PN6 NVARCHAR(50),@DelRowName       NVARCHAR(50),
										@DelRowKindName  NVARCHAR(50)
			------------------------------------------------------
			DECLARE @StartDate      DATE , @EndDate   DATE 
			------------------------------------------------------
			DECLARE  @StartFinanAllocate   SMALLINT     , @EndFinanAllocate   SMALLINT 
			--------------------------------------------------------
		
			SET @StartFinanAllocate = (SELECT  FinancialAllocateID      FROM dbo.FinancialAllocate  WHERE KolNotBookID      = 1 AND FinancialPeriodID = @FinancialPeriodIDFrom   )												  
			SET @EndFinanAllocate   = (SELECT  FinancialAllocateID      FROM dbo.FinancialAllocate  WHERE KolNotBookID      = 1 AND FinancialPeriodID = @FinancialPeriodIDTo     )												  
			-----------------------------------------------------------------
			 IF @FinancialPeriodIDFrom NOT IN ( SELECT FinancialPeriodID FROM  dbo.FinancialPeriod)
					OR 
					@FinancialPeriodIDTo   NOT IN ( SELECT FinancialPeriodID FROM  dbo.FinancialPeriod)
			 BEGIN 
					 RAISERROR (' شناسه ((دوره مالي  )) نامعتبر است  ',18,1)
			 END 
		------------================= جدول موقت بازه هاي زماني براي هر سه نوع ((سالانه ، ماهانه و دوره اي )) گزارش ================---------------------------------------
		    DECLARE @TimeInterval TABLE (PeriodNo		 INT          ,PeriodName    NVARCHAR(200),
				                             Conflict    DECIMAL(26,6),RatioOfChange DECIMAL(26,6),
																		 GrowthRate  DECIMAL(26,6),
				                             StartDate   DATE         ,EndDate       DATE         ,
																		 ShDayCount  TINYINT      ,ShStartDate   VARCHAR(10)  ,
																		 ShEndDate   VARCHAR(10)  ,ShMonthName   NVARCHAR(20) ,
																		 ShYearName  NVARCHAR(20)
				                            )			
			----------------------------------------------------------------------------------------------------------------------------------------------
		    IF @ReportKind = 1 -- Yearly 
				BEGIN 
				   SET @StartDate	      = (SELECT  CAST(FinancialAllocateStartDate AS DATE ) FROM dbo.FinancialAllocate  WHERE FinancialPeriodID = @FinancialPeriodIDFrom )													  
			     SET @EndDate         = (SELECT  CAST(FinancialAllocateEndDate   AS DATE ) FROM dbo.FinancialAllocate  WHERE FinancialPeriodID = @FinancialPeriodIDTo   )	
					 ----------------------------------------------------------------------------------------
				   INSERT INTO @TimeInterval
				      (  PeriodNo,PeriodName, StartDate,  EndDate   )
           SELECT ROW_NUMBER()OVER (ORDER BY FinancialAllocateStartDate) RowNo ,  
                  LTRIM(RTRIM(FinancialPeriodName)) ,FinancialAllocateStartDate , FinancialAllocateEndDate
           FROM dbo.FinancialAllocate  
					      INNER JOIN dbo.FinancialPeriod ON FinancialPeriod.FinancialPeriodID = FinancialAllocate.FinancialPeriodID
					 WHERE FinancialAllocateStartDate >= @StartDate AND FinancialAllocateEndDate <= @EndDate
					 ---------------------------------------------------------------------------------------
					  UPDATE @TimeInterval SET   ShStartDate = (dbo.DateConvertion(StartDate , 'm2s'))
					  UPDATE @TimeInterval SET   ShYearName = SUBSTRING(CAST(ShStartDate AS NCHAR(10)),1,4 )
					  UPDATE @TimeInterval SET   PeriodName = 'سال'+ShYearName
			  END  
			 ------------------------------------------------------------------
			  ELSE IF @ReportKind = 2 -- Monthly 
			  BEGIN 
				    IF @MonthFrom IS NULL OR @MonthTo IS NULL 
						BEGIN 
						    RAISERROR(' مقادریر از ماه تا ماه معتبر وارد نشده ',18,1)
						END 
			    	EXEC dbo.DateInterval
						                    @YearFrom                 ,--@YearFrom = 0,                -- int
			   	                      @MonthFrom                ,--@MonthFrom = 0,               -- int
			   	                      @YearTo                   ,--@YearTo = 0,                  -- int
			   	                      @MonthTo                  ,--@MonthTo = 0,                 -- int
			   	                      @StartDate    OUTPUT      ,--@DateFrom = @DateFrom OUTPUT, -- date
			   	                      @EndDate      OUTPUT       --@DateTo = @DateTo OUTPUT      -- date	 	         	  	
					----------------------------------------------------------------------------------------
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
					 		IF @EndDate < (SELECT FinancialAllocateStartDate FROM dbo.FinancialAllocate  
																WHERE  FinancialAllocateID = @StartFinanAllocate
															 )
								 OR 
								 @EndDate > (SELECT FinancialAllocateEndDate FROM dbo.FinancialAllocate  
														 WHERE FinancialAllocateID = @EndFinanAllocate
														)
							BEGIN 
									 RAISERROR ('  پايان ماه و سال ها در محدوده دوره مالي وارده نيست ',18,1)
							END

					----------------------------------------------------------------------------------------
					 INSERT  INTO @TimeInterval
					       (PeriodNo, StartDate, ShDayCount)
				   SELECT ROW_NUMBER() OVER (ORDER BY MiladiDate) RowNo , MiladiDate,(MonthLen-1)
					 FROM dbo.FxShamsiYearMonth 
           WHERE MiladiDate BETWEEN @StartDate AND @EndDate
					------------------------------------------------
					 UPDATE @TimeInterval SET EndDate     = DATEADD(DAY ,ShDayCount,StartDate)
					 UPDATE @TimeInterval SET ShStartDate = (dbo.DateConvertion(StartDate , 'm2s')) , ShEndDate = (dbo.DateConvertion(EndDate , 'm2s'))
					 UPDATE @TimeInterval SET ShMonthName = CASE WHEN CAST(SUBSTRING(CAST(ShStartDate AS NCHAR(10)),6,2 ) AS TINYINT) = 1  THEN 'فروردين'
					                                             WHEN CAST(SUBSTRING(CAST(ShStartDate AS NCHAR(10)),6,2 ) AS TINYINT) = 2  THEN 'ارديبهشت'
																											 WHEN CAST(SUBSTRING(CAST(ShStartDate AS NCHAR(10)),6,2 ) AS TINYINT) = 3  THEN 'خرداد'
																											 WHEN CAST(SUBSTRING(CAST(ShStartDate AS NCHAR(10)),6,2 ) AS TINYINT) = 4  THEN 'تير'
																											 WHEN CAST(SUBSTRING(CAST(ShStartDate AS NCHAR(10)),6,2 ) AS TINYINT) = 5  THEN 'مرداد'
																											 WHEN CAST(SUBSTRING(CAST(ShStartDate AS NCHAR(10)),6,2 ) AS TINYINT) = 6  THEN 'شهريور'
																											 WHEN CAST(SUBSTRING(CAST(ShStartDate AS NCHAR(10)),6,2 ) AS TINYINT) = 7  THEN 'مهر'
																											 WHEN CAST(SUBSTRING(CAST(ShStartDate AS NCHAR(10)),6,2 ) AS TINYINT) = 8  THEN 'آبان'
																											 WHEN CAST(SUBSTRING(CAST(ShStartDate AS NCHAR(10)),6,2 ) AS TINYINT) = 9  THEN 'آذر'
																											 WHEN CAST(SUBSTRING(CAST(ShStartDate AS NCHAR(10)),6,2 ) AS TINYINT) = 10 THEN 'دي'
																											 WHEN CAST(SUBSTRING(CAST(ShStartDate AS NCHAR(10)),6,2 ) AS TINYINT) = 11 THEN 'بهمن'
																											 WHEN CAST(SUBSTRING(CAST(ShStartDate AS NCHAR(10)),6,2 ) AS TINYINT) = 12 THEN 'اسفند'
																									END ,
																	    ShYearName = SUBSTRING(CAST(ShStartDate AS NCHAR(10)),1,4 )
					UPDATE @TimeInterval  SET PeriodName = ShMonthName +/* ' '+*/ShYearName
			  END
			 		 
			 -------------------------------------------------------------------------
			  ELSE IF @ReportKind = 3 AND @PeriodicDate IS NOT NULL  -- Periodic
			  BEGIN 
				    IF @PeriodicDate IS NULL 
						BEGIN 
						   RAISERROR (' اطلاعات دوره های زمانی  صحیح نمی باشد ',18,1)
						END 
						INSERT INTO @TimeInterval
									(PeriodNo, StartDate,  EndDate   )
			    
						SELECT ROW_NUMBER()OVER (ORDER BY DateFrom ) RowNo , 
									 DateFrom , DateTo 
						FROM OPENJSON(@PeriodicDate)
						WITH (DateFrom   DATE ,DateTo    DATE ) AS P
						----------------------------------------------------------------------
						IF EXISTS (SELECT * FROM @TimeInterval WHERE StartDate  < (SELECT FinancialAllocateStartDate FROM dbo.FinancialAllocate  
															                                          WHERE  FinancialAllocateID = @StartFinanAllocate
														                                          )
																												 OR 
																												 StartDate  > (SELECT FinancialAllocateEndDate FROM dbo.FinancialAllocate  
														                                           WHERE FinancialAllocateID = @EndFinanAllocate
													                                            )
																												 OR 
										                                     EndDate < (SELECT FinancialAllocateStartDate FROM dbo.FinancialAllocate  
																                                    WHERE  FinancialAllocateID = @StartFinanAllocate
															                                     )
								                                         OR 
								                                         EndDate > (SELECT FinancialAllocateEndDate FROM dbo.FinancialAllocate  
														                                        WHERE FinancialAllocateID = @EndFinanAllocate
														                                       )
										 
										 )
						 BEGIN 
						     RAISERROR (' بازه هاي ورودي در محدوده دوره هاي مالي تعيين شده نيستند  ',18,1)
						 END  --SELECT * FROM @TimeInterval --**== 
						----------------------------------------------------------------------
						UPDATE @TimeInterval SET ShStartDate = LTRIM(RTRIM((dbo.DateConvertion(StartDate , 'm2s')))) , ShEndDate = LTRIM(RTRIM((dbo.DateConvertion(EndDate , 'm2s'))))
						-----------------------------------------------------------------------
						UPDATE @TimeInterval SET PeriodName  = 'دوره'+CAST( PeriodNo AS VARCHAR(10))--+':'+'"'+LTRIM(RTRIM(ShStartDate)) +'"' + 'تا' + '"'+LTRIM(RTRIM(ShEndDate))+'"'
						--SELECT * FROM @TimeInterval --**==
			  END 
		-----=================================================================-----
				--SELECT * FROM @TimeInterval --**==	
	
    -------------------------------------------------------------------------------------------------
		CREATE TABLE #CodingList     
		                           (RowNo																					INT													,
                               	AccMTMapID																		BIGINT											,
																GroupCode																			BIGINT											,
																KolCode																				BIGINT											,
																MoeenCode																			BIGINT											,
																GroupName																			NVARCHAR(500)								,
																KolName																				NVARCHAR(500)								,
																MoeenName																			NVARCHAR(500)								,
																AccTafID4																			BIGINT											,
																AccTafID5																			BIGINT											,
																AccTafID6																			BIGINT											,
																AccTafsilName4																NVARCHAR(500)								,
																AccTafsilName5																NVARCHAR(500)								,
																AccTafsilName6																NVARCHAR(500)								,
																CurrencyID                                    SMALLINT										,
																BaseCurrencyID																SMALLINT										,
																CurrencyRate                                  DECIMAL(26,0)								,
																AmountCurrency                                DECIMAL(26,0)								,
																CurrencyChangeRate                            DECIMAL(26,0)								,
																DebitCreditFlag                               BIT													,
																DebitCirculation															DECIMAL(26,0)DEFAULT 0      ,
																CreditCirculation							                DECIMAL(26,0)DEFAULT 0      ,
																RemainAmount 									                DECIMAL(26,0)DEFAULT 0      ,
																CirculationAmount 						                DECIMAL(26,0)DEFAULT 0      ,
																PeriodNo		                                  INT                         ,
																PeriodName                                    NVARCHAR(200)               ,
				                        StartDate                                     DATE                        ,
																EndDate                                       DATE       
															)
		-------------------------------------------------------------------------------------------------
		CREATE TABLE #Comparative       
		                           (RowNo																					INT													,
                               	AccMTMapID																		BIGINT											,
																GroupCode																			BIGINT											,
																KolCode																				BIGINT											,
																MoeenCode																			BIGINT											,
																GroupName																			NVARCHAR(500)								,
																KolName																				NVARCHAR(500)								,
																MoeenName																			NVARCHAR(500)								,
																AccTafID4																			BIGINT											,
																AccTafID5																			BIGINT											,
																AccTafID6																			BIGINT											,
																AccTafsilName4																NVARCHAR(500)								,
																AccTafsilName5																NVARCHAR(500)								,
																AccTafsilName6																NVARCHAR(500)								,
																CurrencyID                                    SMALLINT										,
																BaseCurrencyID																SMALLINT										,
																CurrencyRate                                  DECIMAL(26,0)								,
																AmountCurrency                                DECIMAL(26,0)								,
																CurrencyChangeRate                            DECIMAL(26,0)								,
																DebitCreditFlag                               BIT													,
																DebitCirculation															DECIMAL(26,0)DEFAULT 0      ,
																CreditCirculation							                DECIMAL(26,0)DEFAULT 0      ,
																RemainAmount 									                DECIMAL(26,0)DEFAULT 0      ,
																PeriodNo		                                  INT                         ,
																PeriodName                                    NVARCHAR(200)               ,
				                        StartDate                                     DATE                        ,
																EndDate                                       DATE												,
																Conflict                                      DECIMAL(26,0)               ,
																RatioOfChange                                 DECIMAL(26,0),
																GrowthRate                                    DECIMAL(26,6),     
															)
		-------------------------------------------------------------------------------------------------
		INSERT INTO @AccKindList( AccKind, AccKindCodeName,AccKindName)
		VALUES
		       ( 1,'GroupCode' ,'GroupName'     ),
					 ( 2,'KolCode'   ,'KolName'       ),
					 ( 3,'MoeenCode' ,'MoeenName'     ),
					 ( 4,'AccTafID4' ,'AccTafsilName4'),
					 ( 5,'AccTafID5' ,'AccTafsilName5'),
					 ( 6,'AccTafID6' ,'AccTafsilName6')
  --------------------------------------------------------------------------------------------------------
	 IF @BranchCodeList IS NOT NULL 
	 BEGIN 
	    INSERT INTO  @BranchList ( BrchCode )
	    SELECT * FROM dbo.Split  (@BranchCodeList , ',') 
	 END 
	--------------------------------------------------------------------------------------------------------
	 IF @AccDocKindList IS NOT NULL 
   BEGIN 
	 	 		INSERT INTO @AccDockind( AccdocKindCode)
		    SELECT * FROM Split (@AccDocKindList,',')
   END 
	---------------------------------------------------------------------------------------------------------
	 IF @AccDocStateList IS NOT NULL 
    BEGIN 
	 	 		INSERT INTO @AccDocState	(DocStateID)
	 	 	  SELECT * FROM Split       (@AccDocStateList,',')
    END
		--------------------------------------------------------------------------------------------------------
	 IF @CurrencyIDList IS NOT NULL 
    BEGIN 
	 	 		INSERT INTO @CurrencyList (CurrencyID)
	 	 		SELECT * FROM Split       (@CurrencyIDList,',')
    END
		--------------------------------------------------------------------------------------------------------
		 IF @AccountsPriorityList IS NOT NULL
		BEGIN
        INSERT INTO @AccPriority  (RowNo,AccKind )
        SELECT                     RowNo,AccKind
				FROM OPENJSON(@AccountsPriorityList)
				WITH (RowNo      TINYINT,
				      AccKind    TINYINT
						 ) AS P
			 	----------------------------------------------------------------------------------------------
		  --SELECT * FROM @AccPriority --**==
				UPDATE @AccPriority  
				SET AccKindCodeName = AKCN , AccKindName = AKN
				FROM (
				      SELECT AccKind,AccKindCodeName AKCN , AccKindName  AKN  FROM @AccKindList
				     ) T1
				WHERE T1.AccKind = [@AccPriority].AccKind
				
				----------------------------------------------------------------------------------------------------
				  SET @MaxRow           =  (SELECT MAX(RowNo) FROM @AccPriority )
					SET @DelRow           =  (SELECT AccKind          FROM @AccPriority  WHERE RowNo = @MaxRow AND RowNo > 1 )
					SET @DelRowName       =  (SELECT AccKindName      FROM @AccPriority  WHERE RowNo = @MaxRow AND RowNo > 1 )
					SET @DelRowKindName   =  (SELECT AccKindCodeName  FROM @AccPriority  WHERE RowNo = @MaxRow AND RowNo > 1 ) 
					-------------------------------------------------------------------
					DELETE FROM @AccPriority  WHERE RowNo = @MaxRow AND RowNo > 1 -- حذف اخرين سطح
					--SELECT * FROM @AccPriority --**==
				----------------------------------------------------------------------------------------------
				SET @P1 = (SELECT AccKind FROM @AccPriority WHERE RowNo = 1 ) SET @PN1 = (SELECT AccKindName FROM @AccPriority WHERE RowNo = 1 )
				SET @P2 = (SELECT AccKind FROM @AccPriority WHERE RowNo = 2 ) SET @PN2 = (SELECT AccKindName FROM @AccPriority WHERE RowNo = 2 )
				SET @P3 = (SELECT AccKind FROM @AccPriority WHERE RowNo = 3 ) SET @PN3 = (SELECT AccKindName FROM @AccPriority WHERE RowNo = 3 )
				SET @P4 = (SELECT AccKind FROM @AccPriority WHERE RowNo = 4 ) SET @PN4 = (SELECT AccKindName FROM @AccPriority WHERE RowNo = 4 )
				SET @P5 = (SELECT AccKind FROM @AccPriority WHERE RowNo = 5 ) SET @PN5 = (SELECT AccKindName FROM @AccPriority WHERE RowNo = 5 )
				SET @P6 = (SELECT AccKind FROM @AccPriority WHERE RowNo = 6 ) SET @PN6 = (SELECT AccKindName FROM @AccPriority WHERE RowNo = 6 )
			
		END 
		---------------------------------------------------------------------------------------------------------
		IF @AccountCodeList IS NOT NULL 
		BEGIN 
					---------------------------------------Open JSON Section ------------------------------------------
						DECLARE @AccountList  TABLE         (RowNo   TINYINT ,AccKind    TINYINT,AccCodeList    NVARCHAR(MAX)   )
						DECLARE @AccCodeList  TABLE         (RowNo   TINYINT ,AccKind    TINYINT,AccCode        BIGINT          )
						DECLARE @Temp         SMALLINT      , @AK    TINYINT
						INSERT INTO @AccountList            (RowNo ,AccKind   ,AccCodeList    )
						SELECT ROW_NUMBER() OVER (ORDER BY  AccountsPriorityCode ) RowNo,
									 AccountsPriorityCode    ,AccountCodeList
						FROM    OPENJSON (@AccountCodeList)
						WITH
								 (AccountsPriorityCode   BIGINT     ,AccountCodeList   NVARCHAR(MAX)   ) AS  Opp
					 -------------------------------------------------------------------------------------------------------------------------
					SET @Temp = 1 
					 WHILE @Temp <= (SELECT MAX(rowNo)  FROM  @AccountList )
					 BEGIN 
								SET @AK = (SELECT AccKind FROM  @AccountList WHERE RowNo = @Temp )
								INSERT INTO @AccCodeList
														(RowNo, AccKind,  AccCode )
								SELECT @Temp, @AK , * FROM  dbo.Split ((SELECT AccCodeList FROM @AccountList WHERE RowNo=@Temp ),',')
								SET @Temp = @Temp+1
					 END 
		 END 
		---------------------=========================================================---------------------------
		
			 INSERT INTO #CodingList
				 	   (  RowNo    , AccMTMapID, DebitCirculation, CreditCirculation,  RemainAmount,
					      PeriodNo , PeriodName--, StartDate       , EndDate
					   )
					
			 SELECT ROW_NUMBER() OVER (ORDER BY AccMTMapID  ) RowNo , 
					       T11.AccMTMapID , SUM(T11.DebitAmount) DebitAmount , SUM(T11.CreditAmount) CreditAmount ,ISNULL(SUM(T11.DebitAmount),0) - ISNULL(SUM(T11.CreditAmount),0) , 
								 T11.PeriodNo PNo  , T11.PeriodName PName 
								FROM (
														 SELECT T12.AccMTMapID , CASE WHEN T12.DebitCreditFlag = 1 THEN AccDocDtlAmount ELSE 0  END  DebitAmount 
																									 , CASE WHEN T12.DebitCreditFlag = 0 THEN AccDocDtlAmount ELSE 0  END  CreditAmount ,
																									  T12.PeriodNo  , T12.PeriodName  
														 FROM (
																	 SELECT AccDocDetail.AccMTMapID , ISNULL(SUM(AccDocDetail.AccDocDtlAmount),0)  AccDocDtlAmount , AccDocDetail.DebitCreditFlag,
																	        [@TimeInterval].PeriodNo , [@TimeInterval].PeriodName
																	 FROM   dbo.AccDoc
																	        INNER JOIN  dbo.AccDocDetail  ON AccDocDetail.AccDocID    = AccDoc.AccDocId
																				  INNER JOIN dbo.VWAccMTList     ON VWAccMTList.AccMTMapID = AccDocDetail.AccMTMapID
																					INNER JOIN  @TimeInterval     ON AccDocDate               BETWEEN StartDate  AND EndDate 
																				
																	 WHERE  AccDocState <>0 
																	        AND 
																					(@AccDocKindList_ALL      = 0   OR (AccDocKindCode              IN (SELECT AccdocKindCode FROM @AccDockind )))
																					AND 
																					(@AccDocStateList_ALL     = 0   OR (AccDoc.AccDocState		      IN (SELECT DocStateID     FROM @AccDocState )))
																					AND  
																					(@CurrencyIDList_ALL      = 0   OR (AccDocDetail.CurrencyID     IN (SELECT CurrencyID     FROM @CurrencyList)))
																					AND 
																					(@BranchCodeList_All      = 0   OR (dbo.AccDoc.BranchCode       IN (SELECT BranchCode     FROM @BranchList  )))
																					
																					
																	 GROUP BY [@TimeInterval].PeriodNo, [@TimeInterval].PeriodName,
																	          CASE  WHEN ISNULL(@CurrencyProperty,0) = 1   THEN dbo.AccDocDetail.CurrencyID	 END ,
																		        AccDocDetail.AccMTMapID,AccDocDetail.DebitCreditFlag
														    )T12
											)T11
											GROUP BY PeriodNo,T11.PeriodName ,T11.AccMTMapID		
			------------------------------------------------------------------------------------------
			UPDATE #CodingList 
			SET GroupCode      = GC   , GroupName  = GN  , KolCode         = KC   , KolName   = KN ,MoeenCode = MC,MoeenName = MN ,AccTafID4 = AT4 ,
			    AccTafsilName4 = ATN4 , AccTafID5  = AT5 , AccTafsilName5  = ATN5 , AccTafID6 = AT6,AccTafsilName6  = ATN6
			FROM 
			    (
					 SELECT AccMTMapID    , GroupCode GC        , GroupName GN , KolCode KC           , KolName    KN  ,MoeenCode       MC , MoeenName MN,
					        AccTafID4 AT4 , AccTafsilName4 ATN4 , AccTafID5 AT5, AccTafsilName5  ATN5 , AccTafID6  AT6 , AccTafsilName6 ATN6
					 FROM dbo.VWAccMTList
					)TA
			WHERE TA.AccMTMapID = #CodingList.AccMTMapID 
		 	-------------------------------------------------
								--	SELECT 1 a ,  * FROM #CodingList -- WHERE AccMTMapID = 96 -- MoeenCode = 101001 AND AccTafID4 = 13000021 --**==
			DELETE FROM #CodingList WHERE PeriodNo IS NULL 
		  -----------------------------------------------
					
		------------------------------------------------------------------------------------------------------------------------------
		 IF EXISTS (SELECT  * FROM @AccountList )
			 BEGIN 
					 IF EXISTS (SELECT * FROM @AccountList  WHERE AccKind = 1)
					 BEGIN 
							DELETE FROM #CodingList 
							WHERE GroupCode NOT IN (SELECT AccCode FROM @AccCodeList WHERE AccKind = 1 )
					 END 
					 ----------------------------------------------------------------------
					 IF EXISTS (SELECT * FROM @AccountList  WHERE AccKind = 2)
					 BEGIN 
							DELETE FROM #CodingList 
							WHERE KolCode NOT IN (SELECT AccCode FROM @AccCodeList WHERE AccKind = 2 )
					 END      
					 ------------------------------------------------------------------------
					 IF EXISTS (SELECT * FROM @AccountList  WHERE AccKind = 3)
					 BEGIN 
							DELETE FROM #CodingList 
							WHERE MoeenCode NOT IN (SELECT AccCode FROM @AccCodeList WHERE AccKind = 3 )
					 END 
					 -------------------------------------------------------------------------------
					 IF EXISTS (SELECT * FROM @AccountList  WHERE AccKind = 4)
					 BEGIN 
							DELETE FROM #CodingList 
							WHERE  AccTafID4 NOT IN (SELECT AccCode FROM @AccCodeList WHERE AccKind = 4 )
					 END 
					 --------------------------------------------------------------------------------
					 IF EXISTS (SELECT * FROM @AccountList  WHERE AccKind = 5)
					 BEGIN 
							DELETE FROM #CodingList 
							WHERE AccTafID5 NOT IN (SELECT AccCode FROM @AccCodeList WHERE AccKind = 5 )
					 END 
					 -------------------------------------------------------------------------------
					 IF EXISTS (SELECT * FROM @AccountList  WHERE AccKind = 6)
					 BEGIN 
							DELETE FROM #CodingList 
							WHERE AccTafID6 NOT IN (SELECT AccCode FROM @AccCodeList WHERE AccKind = 6 )
					 END 
				 -------------------------------------------------------------------------------
			 END 
			------------------------------------------------------------------------------------------------------------------------------
		 IF (SELECT COUNT(*) FROM @AccPriority) > 0 
		 BEGIN
					INSERT INTO #Comparative
										 (RowNo            ,GroupCode         ,KolCode      ,MoeenCode ,AccTafID4  ,AccTafID5 ,AccTafID6  ,
											DebitCirculation ,CreditCirculation ,RemainAmount ,PeriodNo  ,PeriodName  --,StartDate ,EndDate
										
										)
		   
					SELECT  ROW_NUMBER() OVER 
				                         (PARTITION BY 
																               CASE   WHEN @P1 = 1 THEN C1 WHEN @P2 = 1  THEN C2
																											WHEN @P3 = 1 THEN C3 WHEN @P4 = 1  THEN C4
																											WHEN @P5 = 1 THEN C5 WHEN @P6 = 1  THEN C6
																								END ,
																								CASE  WHEN @P1 = 2 THEN C1 WHEN @P2 = 2  THEN C2
																											WHEN @P3 = 2 THEN C3 WHEN @P4 = 2  THEN C4
																											WHEN @P5 = 2 THEN C5 WHEN @P6 = 2  THEN C6
																								END ,
																								CASE  WHEN @P1 = 3 THEN C1 WHEN @P2 = 3  THEN C2
																											WHEN @P3 = 3 THEN C3 WHEN @P4 = 3  THEN C4
																											WHEN @P5 = 3 THEN C5 WHEN @P6 = 3  THEN C6
																								END ,
				
																								CASE  WHEN @P1 = 4 THEN C1 WHEN @P2 = 4  THEN C2
																											WHEN @P3 = 4 THEN C3 WHEN @P4 = 4  THEN C4
																											WHEN @P5 = 4 THEN C5 WHEN @P6 = 4  THEN C6
																								END ,
																								CASE  WHEN @P1 = 5 THEN C1 WHEN @P2 = 5  THEN C2
																											WHEN @P3 = 5 THEN C3 WHEN @P4 = 5  THEN C4
																											WHEN @P5 = 5 THEN C5 WHEN @P6 = 5  THEN C6
																								END ,
																								CASE  WHEN @P1 = 6 THEN C1 WHEN @P2 = 6  THEN C2
																											WHEN @P3 = 6 THEN C3 WHEN @P4 = 6  THEN C4
																											WHEN @P5 = 6 THEN C5 WHEN @P6 = 6  THEN C6
																								END
				                           ORDER BY 
																	         CASE       WHEN @P1 = 1 THEN C1 WHEN @P2 = 1  THEN C2
																											WHEN @P3 = 1 THEN C3 WHEN @P4 = 1  THEN C4
																											WHEN @P5 = 1 THEN C5 WHEN @P6 = 1  THEN C6
																								END ,
																								CASE  WHEN @P1 = 2 THEN C1 WHEN @P2 = 2  THEN C2
																											WHEN @P3 = 2 THEN C3 WHEN @P4 = 2  THEN C4
																											WHEN @P5 = 2 THEN C5 WHEN @P6 = 2  THEN C6
																								END ,
																								CASE  WHEN @P1 = 3 THEN C1 WHEN @P2 = 3  THEN C2
																											WHEN @P3 = 3 THEN C3 WHEN @P4 = 3  THEN C4
																											WHEN @P5 = 3 THEN C5 WHEN @P6 = 3  THEN C6
																								END ,
				
																								CASE  WHEN @P1 = 4 THEN C1 WHEN @P2 = 4  THEN C2
																											WHEN @P3 = 4 THEN C3 WHEN @P4 = 4  THEN C4
																											WHEN @P5 = 4 THEN C5 WHEN @P6 = 4  THEN C6
																								END ,
																								CASE  WHEN @P1 = 5 THEN C1 WHEN @P2 = 5  THEN C2
																											WHEN @P3 = 5 THEN C3 WHEN @P4 = 5  THEN C4
																											WHEN @P5 = 5 THEN C5 WHEN @P6 = 5  THEN C6
																								END ,
																								CASE  WHEN @P1 = 6 THEN C1 WHEN @P2 = 6  THEN C2
																											WHEN @P3 = 6 THEN C3 WHEN @P4 = 6  THEN C4
																											WHEN @P5 = 6 THEN C5 WHEN @P6 = 6  THEN C6
																								END ,PeriodNo , PeriodName
														     )   RowNo, 
								CASE  WHEN ISNULL(@P1, @DelRow) = 1 THEN C1 WHEN ISNULL(@P2, @DelRow) = 1  THEN C2
											WHEN ISNULL(@P3, @DelRow) = 1 THEN C3 WHEN ISNULL(@P4, @DelRow) = 1  THEN C4
											WHEN ISNULL(@P5, @DelRow) = 1 THEN C5 WHEN ISNULL(@P6, @DelRow) = 1  THEN C6
						  	END ,
								CASE  WHEN ISNULL(@P1, @DelRow) = 2 THEN C1 WHEN ISNULL(@P2, @DelRow) = 2  THEN C2
											WHEN ISNULL(@P3, @DelRow) = 2 THEN C3 WHEN ISNULL(@P4, @DelRow) = 2  THEN C4
											WHEN ISNULL(@P5, @DelRow) = 2 THEN C5 WHEN ISNULL(@P6, @DelRow) = 2  THEN C6
								END ,
								CASE  WHEN ISNULL(@P1, @DelRow) = 3 THEN C1 WHEN ISNULL(@P2, @DelRow) = 3  THEN C2
											WHEN ISNULL(@P3, @DelRow) = 3 THEN C3 WHEN ISNULL(@P4, @DelRow) = 3  THEN C4
											WHEN ISNULL(@P5, @DelRow) = 3 THEN C5 WHEN ISNULL(@P6, @DelRow) = 3  THEN C6
								END ,
				
								CASE    WHEN ISNULL(@P1, @DelRow)   = 4 THEN C1 WHEN ISNULL(@P2, @DelRow )   = 4  THEN C2
											  WHEN ISNULL(@P3,@DelRow)    = 4 THEN C3 WHEN ISNULL(@P4,@DelRow)     = 4  THEN C4
											  WHEN ISNULL(@P5,@DelRow)    = 4 THEN C5 WHEN ISNULL(@P6,@DelRow)     = 4  THEN C6
								END ,
								CASE    WHEN ISNULL(@P1, @DelRow)   = 5 THEN C1 WHEN ISNULL(@P2, @DelRow )   = 5  THEN C2
											  WHEN ISNULL(@P3,@DelRow)    = 5 THEN C3 WHEN ISNULL(@P4,@DelRow)     = 5  THEN C4
											  WHEN ISNULL(@P5,@DelRow)    = 5 THEN C5 WHEN ISNULL(@P6,@DelRow)     = 5  THEN C6
								END ,
								CASE    WHEN ISNULL(@P1, @DelRow)   = 6 THEN C1 WHEN ISNULL(@P2, @DelRow )   = 6  THEN C2
											  WHEN ISNULL(@P3,@DelRow)    = 6 THEN C3 WHEN ISNULL(@P4,@DelRow)     = 6  THEN C4
											  WHEN ISNULL(@P5,@DelRow)    = 6 THEN C5 WHEN ISNULL(@P6,@DelRow)     = 6  THEN C6
								END ,
					       T.DebitCirculation , T.CreditCirculation,T.RemainAmount , PeriodNo  ,PeriodName
	        FROM (		
			          SELECT  
									      CASE  WHEN @P1     = 1 THEN GroupCode WHEN @P1     = 2 THEN KolCode   
															WHEN @P1     = 3 THEN MoeenCode WHEN @P1     = 4 THEN AccTafID4
															WHEN @P1     = 5 THEN AccTafID5 WHEN @P1     = 6 THEN AccTafID6
															WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
															WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 						WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
												END  C1
														--------------------------------------------------------
												,CASE WHEN @P2     = 1 THEN GroupCode WHEN @P2      = 2 THEN KolCode
															WHEN @P2     = 3 THEN MoeenCode WHEN @P2      = 4 THEN AccTafID4
									 						WHEN @P2     = 5 THEN AccTafID5 WHEN @P2      = 6 THEN AccTafID6
															WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow  = 2 THEN KolCode
															WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow  = 4 THEN AccTafID4
									 						WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow  = 6 THEN AccTafID6
												END  C2
														--------------------------------------------------------
												,CASE WHEN @P3     = 1 THEN GroupCode WHEN @P3     = 2 THEN KolCode
															WHEN @P3     = 3 THEN MoeenCode WHEN @P3     = 4 THEN AccTafID4
									 						WHEN @P3     = 5 THEN AccTafID5 WHEN @P3     = 6 THEN AccTafID6
															WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
															WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 						WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
												END  C3
														--------------------------------------------------------
												,CASE WHEN @P4		 = 1 THEN GroupCode WHEN @P4		 = 2 THEN KolCode 
															WHEN @P4     = 3 THEN MoeenCode WHEN @P4     = 4 THEN AccTafID4
									 						WHEN @P4     = 5 THEN AccTafID5 WHEN @P4		 = 6 THEN AccTafID6
															WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
															WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 						WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
												END C4
												--------------------------------------------------------
												,CASE WHEN @P5		 = 1 THEN GroupCode WHEN @P5		 = 2 THEN KolCode
															WHEN @P5		 = 3 THEN MoeenCode WHEN @P5		 = 4 THEN AccTafID4
									 						WHEN @P5		 = 5 THEN AccTafID5 WHEN @P5		 = 6 THEN AccTafID6
															WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
															WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 						WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
												END  C5
												--------------------------------------------------------
												,CASE WHEN @P6		 = 1 THEN GroupCode WHEN @P6     = 2 THEN KolCode 
															WHEN @P6		 = 3 THEN MoeenCode WHEN @P6     = 4 THEN AccTafID4
									 						WHEN @P6		 = 5 THEN AccTafID5 WHEN @P6		 = 6 THEN AccTafID6
															WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
															WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 						WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
												END   C6  ,
									SUM(DebitCirculation) DebitCirculation  , SUM(CreditCirculation) CreditCirculation,
									SUM(RemainAmount)     RemainAmount      ,PeriodNo , PeriodName
				  FROM #CodingList
			    GROUP BY            CASE  WHEN @P1     = 1 THEN GroupCode WHEN @P1     = 2 THEN KolCode
																		WHEN @P1     = 3 THEN MoeenCode WHEN @P1     = 4 THEN AccTafID4
																		WHEN @P1     = 5 THEN AccTafID5 WHEN @P1     = 6 THEN AccTafID6
																		WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
																		WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 									WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
															 	,CASE WHEN @P2     = 1 THEN GroupCode WHEN @P2     = 2 THEN KolCode
																			WHEN @P2     = 3 THEN MoeenCode WHEN @P2     = 4 THEN AccTafID4
									 										WHEN @P2     = 5 THEN AccTafID5 WHEN @P2     = 6 THEN AccTafID6
																			WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
																			WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 										WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
																,CASE WHEN @P3     = 1 THEN GroupCode WHEN @P3     = 2 THEN KolCode
																			WHEN @P3     = 3 THEN MoeenCode WHEN @P3     = 4 THEN AccTafID4
									 										WHEN @P3     = 5 THEN AccTafID5 WHEN @P3     = 6 THEN AccTafID6
																			WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
																			WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 										WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
																,CASE WHEN @P4     = 1 THEN GroupCode WHEN @P4      = 2 THEN KolCode 
																			WHEN @P4     = 3 THEN MoeenCode WHEN @P4      = 4 THEN AccTafID4
									 										WHEN @P4     = 5 THEN AccTafID5 WHEN @P4      = 6 THEN AccTafID6
																			WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow  = 2 THEN KolCode
																			WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow  = 4 THEN AccTafID4
									 										WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow  = 6 THEN AccTafID6
																END 
																--------------------------------------------------------
																,CASE WHEN @P5     = 1 THEN GroupCode WHEN @P5     = 2 THEN KolCode
																			WHEN @P5     = 3 THEN MoeenCode WHEN @P5     = 4 THEN AccTafID4
									 										WHEN @P5     = 5 THEN AccTafID5 WHEN @P5     = 6 THEN AccTafID6
																			WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
																			WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 										WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
																END 
																--------------------------------------------------------
																,CASE WHEN @P6     = 1 THEN GroupCode WHEN @P6     = 2 THEN KolCode 
																			WHEN @P6     = 3 THEN MoeenCode WHEN @P6     = 4 THEN AccTafID4
									 										WHEN @P6     = 5 THEN AccTafID5 WHEN @P6     = 6 THEN AccTafID6
																			WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
																			WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 										WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
																END,
															PeriodNo , PeriodName
				) T
				
          IF EXISTS (SELECT GroupCode FROM #Comparative WHERE GroupCode IS NOT NULL)
					BEGIN 
					    UPDATE  #Comparative SET GroupName = GN
							FROM (
							      SELECT AccCode , AccName GN   FROM dbo.AccCoding 
							     )T1
							WHERE T1.AccCode = #Comparative.GroupCode
		      END 
					-----------------------------------------------------------
					IF EXISTS (SELECT KolCode FROM #Comparative WHERE KolCode IS NOT NULL)
					BEGIN 
					    UPDATE  #Comparative SET KolName = KN
							FROM (
							      SELECT AccCode , AccName KN   FROM dbo.AccCoding 
							     )T1
							WHERE T1.AccCode = #Comparative.KolCode
		      END 
					-----------------------------------------------------------
					IF EXISTS (SELECT MoeenCode FROM #Comparative WHERE MoeenCode IS NOT NULL)
					BEGIN 
					    UPDATE  #Comparative SET MoeenName = MN
							FROM (
							      SELECT AccCode , AccName MN   FROM dbo.AccCoding 
							     )T1
							WHERE T1.AccCode = #Comparative.MoeenCode
		      END 
				-----------------------------------------------------------
					IF EXISTS (SELECT AccTafID4 FROM #Comparative WHERE AccTafID4 IS NOT NULL)
					BEGIN 
					    UPDATE  #Comparative SET AccTafsilName4 = AT4
							FROM (
							      SELECT AccTafID , AccTafsilName AT4   FROM dbo.AccTafsil 
							     )T1
							WHERE T1.AccTafID = #Comparative.AccTafID4
		      END 
					--------------------------------------------------------------
					IF EXISTS (SELECT AccTafID5 FROM #Comparative WHERE AccTafID5 IS NOT NULL)
					BEGIN 
					    UPDATE  #Comparative SET AccTafsilName5 = AT5
							FROM (
							      SELECT AccTafID , AccTafsilName AT5   FROM dbo.AccTafsil 
							     )T1
							WHERE T1.AccTafID = #Comparative.AccTafID5
		      END 
				--------------------------------------------------------------
					IF EXISTS (SELECT AccTafID6 FROM #Comparative WHERE AccTafID6 IS NOT NULL)
					BEGIN 
					    UPDATE  #Comparative SET AccTafsilName5 = AT6
							FROM (
							      SELECT AccTafID , AccTafsilName AT6   FROM dbo.AccTafsil 
							     )T1
							WHERE T1.AccTafID = #Comparative.AccTafID6
		      END 
				--------------------------------------------------------------

	 END 
	-----------------------------------------------------------------------
	   CREATE TABLE  #AnalyzeTbl   
			                         (--RowNo																					INT													,
                               	--AccMTMapID																		BIGINT											,
																GroupCode																			BIGINT											,
																GroupName																			NVARCHAR(500)								,
																KolCode																				BIGINT											,
																KolName																				NVARCHAR(500)								,
																MoeenCode																			BIGINT											,
																MoeenName																			NVARCHAR(500)								,
																AccTafID4																			BIGINT											,
																AccTafsilName4																NVARCHAR(500)								,
																AccTafID5																			BIGINT											,
																AccTafsilName5																NVARCHAR(500)								,
																AccTafID6																			BIGINT											,
																AccTafsilName6																NVARCHAR(500)								
														   )
	 
	    
      
			 -----------------------------------------------------------------------------------
			-- SELECT * FROM  #AnalyzeTbl --**==
				DECLARE @IntervalRow   SMALLINT      ,@ColName     NVARCHAR(200),@ColNameA        NVARCHAR(200),
				        @AddCol        NVARCHAR(1000),@MaxInterval SMALLINT     ,@ColNameBefore   NVARCHAR(200)
						    --@ColName
				SET @IntervalRow = 1 SET @MaxInterval = (SELECT ISNULL(MAX(PeriodNo),0) FROM @TimeInterval)
			------------------------------------------------------------------------------
				WHILE @IntervalRow <= @MaxInterval
				BEGIN 
				   SET @ColName          = (SELECT PeriodName FROM @TimeInterval WHERE PeriodNo = @IntervalRow)
				--	 SELECT @ColName--**==
					 SET @AddCol           = 'ALTER TABLE #AnalyzeTbl ADD   '+ CAST(@ColName AS NVARCHAR(50)) +'  DECIMAL(26,6) '--'ALTER TABLE #AnalyzeTbl ADD   '+ CAST(@ColName AS NVARCHAR(50)) +'  DECIMAL(26,6) '
					 EXEC (@AddCol)
					 ---------------------------------------------------
					 --SET @AddCol           = 'ALTER TABLE #AnalyzeTbl2 ADD   '+ CAST(@ColName AS NVARCHAR(50)) +'  DECIMAL(26,6) '
					 --EXEC (@AddCol)
						---------------------------------------------------
					 /*IF @IntervalRow >1 AND @IntervalRow <> @MaxInterval
					 BEGIN
					     SET  @ColNameA  = ' مغایرت' + @ColNameBefore + 'با'+@ColName
							 --SELECT @ColName --**==
							 SET  @AddCol   = 'ALTER TABLE #AnalyzeTbl ADD   '+ @ColNameA +'  DECIMAL(26,6) '
					     EXEC (@AddCol)
							 ----------------------------------------------------------------------------------- 
					     SET  @ColNameA = @ColName +'A'
					     SET  @AddCol   = 'ALTER TABLE #AnalyzeTbl ADD   '+ @ColNameA +'  DECIMAL(26,6) '
					     EXEC (@AddCol)
							 
					 END
					 SET @ColNameBefore   = @ColName*/
					 SET @IntervalRow = @IntervalRow+1  
				END 
				---------------------------------
				-- SELECT * FROM  #AnalyzeTbl --**==
				DECLARE @ColList TABLE ( ColumnID MONEY ,ColumnName NVARCHAR(200))
					 ----------------------------------------------------------------
				INSERT INTO @ColList   ( ColumnID,ColumnName)
				SELECT column_id,name 
				FROM tempdb.sys.columns 
				WHERE [object_id] = OBJECT_ID(N'tempdb..#AnalyzeTbl');
			 IF @ReportNature = 2 
	     BEGIN
				 --SELECT * FROM @ColList --**==
		------------------------------------------------------------------------------
					IF @ConflictOfTwoPeriods = 1 
					BEGIN 
							IF @AccAmountDisPlayNature			= 1 -- 1 = Remain Kind  , 2 = Debit Circulation Kind  , 3= CreditcirculationKind 
							BEGIN 
									UPDATE #Comparative 
									SET Conflict = ISNULL(CT,0) - ISNULL(RemainAmount,0)
									FROM (
												SELECT ISNULL(GroupCode,0) Groupcode ,ISNULL(KolCode,0)      KolCode   ,ISNULL(MoeenCode,0) Moeencode,
																ISNULL(AccTafID4,0) AcctafID4 ,ISNULL(AccTafID5,0)    AccTafID5 ,ISNULL(AccTafID6,0) AcctafID6,
																PeriodNo                      ,ISNULL(RemainAmount,0) CT   
												FROM #Comparative 
												) TA10
									WHERE TA10.Groupcode        =  ISNULL(#Comparative.GroupCode   ,0)
												AND 
												TA10.KolCode          =  ISNULL(#Comparative.KolCode     ,0)
												AND 
												TA10.Moeencode        =  ISNULL(#Comparative.MoeenCode   ,0)
												AND 
												TA10.AcctafID4        =  ISNULL(#Comparative.AccTafID4   ,0)
												AND 
												TA10.AccTafID5        =  ISNULL(#Comparative.AccTafID5   ,0) 
												AND 
												TA10.AccTafID6        =  ISNULL(#Comparative.AccTafID6   ,0)
												AND 
												#Comparative.PeriodNo =  TA10.PeriodNo - 1 
									UPDATE #Comparative SET Conflict = RemainAmount * -1 WHERE Conflict IS NULL 
							END 
							-------------------------------------------
							IF @AccAmountDisPlayNature			= 2 -- 1 = Remain Kind  , 2 = Debit Circulation Kind  , 3= CreditcirculationKind 
							BEGIN 
									UPDATE #Comparative 
									SET Conflict = ISNULL(CT,0) - ISNULL(DebitCirculation,0)
									FROM (
												SELECT ISNULL(GroupCode,0) Groupcode ,ISNULL(KolCode,0)      KolCode   ,ISNULL(MoeenCode,0) Moeencode,
																ISNULL(AccTafID4,0) AcctafID4 ,ISNULL(AccTafID5,0)    AccTafID5 ,ISNULL(AccTafID6,0) AcctafID6,
																PeriodNo                      ,ISNULL(DebitCirculation,0) CT   
												FROM #Comparative 
												) TA10
									WHERE TA10.Groupcode        =  ISNULL(#Comparative.GroupCode   ,0)
												AND 
												TA10.KolCode          =  ISNULL(#Comparative.KolCode     ,0)
												AND 
												TA10.Moeencode        =  ISNULL(#Comparative.MoeenCode   ,0)
												AND 
												TA10.AcctafID4        =  ISNULL(#Comparative.AccTafID4   ,0)
												AND 
												TA10.AccTafID5        =  ISNULL(#Comparative.AccTafID5   ,0) 
												AND 
												TA10.AccTafID6        =  ISNULL(#Comparative.AccTafID6   ,0)
												AND 
												#Comparative.PeriodNo =  TA10.PeriodNo - 1 
									UPDATE #Comparative SET Conflict = DebitCirculation * -1 WHERE Conflict IS NULL 
							END 
							-----------------------------------------------
							IF @AccAmountDisPlayNature			= 3 -- 1 = Remain Kind  , 2 = Debit Circulation Kind  , 3= CreditcirculationKind 
							BEGIN 
									UPDATE #Comparative 
									SET Conflict = ISNULL(CT,0) - ISNULL(CreditCirculation,0)
									FROM (
												SELECT ISNULL(GroupCode,0) Groupcode ,ISNULL(KolCode,0)      KolCode   ,ISNULL(MoeenCode,0) Moeencode,
																ISNULL(AccTafID4,0) AcctafID4 ,ISNULL(AccTafID5,0)    AccTafID5 ,ISNULL(AccTafID6,0) AcctafID6,
																PeriodNo                      ,ISNULL(CreditCirculation,0) CT   
												FROM #Comparative 
												) TA10
									WHERE TA10.Groupcode        =  ISNULL(#Comparative.GroupCode   ,0)
												AND 
												TA10.KolCode          =  ISNULL(#Comparative.KolCode     ,0)
												AND 
												TA10.Moeencode        =  ISNULL(#Comparative.MoeenCode   ,0)
												AND 
												TA10.AcctafID4        =  ISNULL(#Comparative.AccTafID4   ,0)
												AND 
												TA10.AccTafID5        =  ISNULL(#Comparative.AccTafID5   ,0) 
												AND 
												TA10.AccTafID6        =  ISNULL(#Comparative.AccTafID6   ,0)
												AND 
												#Comparative.PeriodNo =  TA10.PeriodNo - 1 
									UPDATE #Comparative SET Conflict = CreditCirculation * -1 WHERE Conflict IS NULL 
							END 
					END 
					--------==================================-------------
					IF @RatioOfChange = 1 
					BEGIN 
							 IF @AccAmountDisPlayNature			= 1 -- 1 = Remain Kind  , 2 = Debit Circulation Kind  , 3= CreditcirculationKind 
							 BEGIN 
									UPDATE #Comparative 
									SET RatioOfChange = ISNULL(CT,0) - ISNULL(RemainAmount,0)/CASE WHEN  ISNULL(RemainAmount,0)  = 0 THEN 1 ELSE ISNULL(RemainAmount,0) END 
									FROM (
												SELECT ISNULL(GroupCode,0) Groupcode  ,ISNULL(KolCode,0)      KolCode   ,ISNULL(MoeenCode,0) Moeencode,
																ISNULL(AccTafID4,0) AcctafID4 ,ISNULL(AccTafID5,0)    AccTafID5 ,ISNULL(AccTafID6,0) AcctafID6,
																PeriodNo                      ,ISNULL(RemainAmount     ,0) 
																															 /*CASE WHEN @AccAmountDisPlayNature = 1 THEN ISNULL(RemainAmount     ,0)
																																		WHEN @AccAmountDisPlayNature = 2 THEN ISNULL(DebitCirculation ,0)
																																		WHEN @AccAmountDisPlayNature = 3 THEN ISNULL(CreditCirculation,0)
																															 END*/  CT   
												FROM #Comparative 
												) TA10
									WHERE TA10.Groupcode        =  ISNULL(#Comparative.GroupCode   ,0)
												AND 
												TA10.KolCode          =  ISNULL(#Comparative.KolCode     ,0)
												AND 
												TA10.Moeencode        =  ISNULL(#Comparative.MoeenCode   ,0)
												AND 
												TA10.AcctafID4        =  ISNULL(#Comparative.AccTafID4   ,0)
												AND 
												TA10.AccTafID5        =  ISNULL(#Comparative.AccTafID5   ,0) 
												AND 
												TA10.AccTafID6        =  ISNULL(#Comparative.AccTafID6   ,0)
												AND 
												#Comparative.PeriodNo =  TA10.PeriodNo - 1 
									UPDATE #Comparative SET RatioOfChange =  1 WHERE RatioOfChange IS NULL 
							END 
							----------------------------------------------------------
							 IF @AccAmountDisPlayNature			= 2 -- 1 = Remain Kind  , 2 = Debit Circulation Kind  , 3= CreditcirculationKind 
							 BEGIN 
									UPDATE #Comparative 
									SET RatioOfChange = ISNULL(CT,0) - ISNULL(DebitCirculation,0)/CASE WHEN  ISNULL(DebitCirculation,0)  = 0 THEN 1 ELSE ISNULL(DebitCirculation,0) END 
									FROM (
												SELECT ISNULL(GroupCode,0) Groupcode ,ISNULL(KolCode,0)      KolCode   ,ISNULL(MoeenCode,0) Moeencode,
																ISNULL(AccTafID4,0) AcctafID4 ,ISNULL(AccTafID5,0)    AccTafID5 ,ISNULL(AccTafID6,0) AcctafID6,
																PeriodNo                      ,ISNULL(DebitCirculation     ,0) 
																															 /*CASE WHEN @AccAmountDisPlayNature = 1 THEN ISNULL(RemainAmount     ,0)
																																		WHEN @AccAmountDisPlayNature = 2 THEN ISNULL(DebitCirculation ,0)
																																		WHEN @AccAmountDisPlayNature = 3 THEN ISNULL(CreditCirculation,0)
																															 END*/  CT   
												FROM #Comparative 
												) TA10
									WHERE TA10.Groupcode        =  ISNULL(#Comparative.GroupCode   ,0)
												AND 
												TA10.KolCode          =  ISNULL(#Comparative.KolCode     ,0)
												AND 
												TA10.Moeencode        =  ISNULL(#Comparative.MoeenCode   ,0)
												AND 
												TA10.AcctafID4        =  ISNULL(#Comparative.AccTafID4   ,0)
												AND 
												TA10.AccTafID5        =  ISNULL(#Comparative.AccTafID5   ,0) 
												AND 
												TA10.AccTafID6        =  ISNULL(#Comparative.AccTafID6   ,0)
												AND 
												#Comparative.PeriodNo =  TA10.PeriodNo - 1 
									UPDATE #Comparative SET RatioOfChange =  1 WHERE RatioOfChange IS NULL 
							END 
							---------------------------------------------------------------
							 IF @AccAmountDisPlayNature			= 3 -- 1 = Remain Kind  , 2 = Debit Circulation Kind  , 3= CreditcirculationKind 
							 BEGIN 
									UPDATE #Comparative 
									SET RatioOfChange = ISNULL(CT,0) - ISNULL(CreditCirculation,0)/CASE WHEN  ISNULL(CreditCirculation,0)  = 0 THEN 1 ELSE ISNULL(CreditCirculation,0) END 
									FROM (
												SELECT ISNULL(GroupCode,0) Groupcode  ,ISNULL(KolCode,0)       KolCode   ,ISNULL(MoeenCode,0) Moeencode,
																ISNULL(AccTafID4,0) AcctafID4 ,ISNULL(AccTafID5,0)    AccTafID5 ,ISNULL(AccTafID6,0) AcctafID6,
																PeriodNo                      ,ISNULL(CreditCirculation,0) 
																															 /*CASE WHEN @AccAmountDisPlayNature = 1 THEN ISNULL(RemainAmount     ,0)
																																		WHEN @AccAmountDisPlayNature = 2 THEN ISNULL(DebitCirculation ,0)
																																		WHEN @AccAmountDisPlayNature = 3 THEN ISNULL(CreditCirculation,0)
																															 END*/  CT   
												FROM #Comparative 
												) TA10
									WHERE TA10.Groupcode        =  ISNULL(#Comparative.GroupCode   ,0)
												AND 
												TA10.KolCode          =  ISNULL(#Comparative.KolCode     ,0)
												AND 
												TA10.Moeencode        =  ISNULL(#Comparative.MoeenCode   ,0)
												AND 
												TA10.AcctafID4        =  ISNULL(#Comparative.AccTafID4   ,0)
												AND 
												TA10.AccTafID5        =  ISNULL(#Comparative.AccTafID5   ,0) 
												AND 
												TA10.AccTafID6        =  ISNULL(#Comparative.AccTafID6   ,0)
												AND 
												#Comparative.PeriodNo =  TA10.PeriodNo - 1 
									UPDATE #Comparative SET RatioOfChange =  1 WHERE RatioOfChange IS NULL 
							END 
					END 
					--------==================================--------------
					IF @GrowthRate = 1
					BEGIN 
							IF @AccAmountDisPlayNature			= 1 -- 1 = Remain Kind  , 2 = Debit Circulation Kind  , 3= CreditcirculationKind 
							 BEGIN 
									UPDATE #Comparative 
									SET GrowthRate = ISNULL(CT,0) /CASE WHEN  ISNULL(RemainAmount,0)  = 0 THEN 1 ELSE ISNULL(RemainAmount,0) END 
									FROM (
												SELECT ISNULL(GroupCode,0) Groupcode  ,ISNULL(KolCode,0)      KolCode   ,ISNULL(MoeenCode,0) Moeencode,
																ISNULL(AccTafID4,0) AcctafID4 ,ISNULL(AccTafID5,0)    AccTafID5 ,ISNULL(AccTafID6,0) AcctafID6,
																PeriodNo                      ,ISNULL(RemainAmount     ,0) 
																															 /*CASE WHEN @AccAmountDisPlayNature = 1 THEN ISNULL(RemainAmount     ,0)
																																		WHEN @AccAmountDisPlayNature = 2 THEN ISNULL(DebitCirculation ,0)
																																		WHEN @AccAmountDisPlayNature = 3 THEN ISNULL(CreditCirculation,0)
																															 END*/  CT   
												FROM #Comparative 
												) TA10
									WHERE TA10.Groupcode        =  ISNULL(#Comparative.GroupCode   ,0)
												AND 
												TA10.KolCode          =  ISNULL(#Comparative.KolCode     ,0)
												AND 
												TA10.Moeencode        =  ISNULL(#Comparative.MoeenCode   ,0)
												AND 
												TA10.AcctafID4        =  ISNULL(#Comparative.AccTafID4   ,0)
												AND 
												TA10.AccTafID5        =  ISNULL(#Comparative.AccTafID5   ,0) 
												AND 
												TA10.AccTafID6        =  ISNULL(#Comparative.AccTafID6   ,0)
												AND 
												#Comparative.PeriodNo =  TA10.PeriodNo - 1 
									UPDATE #Comparative SET GrowthRate = ISNULL(RemainAmount,0)*- 1 WHERE GrowthRate IS NULL 
							END
							--------------------------------------------------------------------------
							IF @AccAmountDisPlayNature			= 2 -- 1 = Remain Kind  , 2 = Debit Circulation Kind  , 3= CreditcirculationKind 
							 BEGIN 
									UPDATE #Comparative 
									SET GrowthRate = ISNULL(CT,0) /CASE WHEN  ISNULL(DebitCirculation,0)  = 0 THEN 1 ELSE ISNULL(DebitCirculation,0) END 
									FROM (
												SELECT ISNULL(GroupCode,0) Groupcode ,ISNULL(KolCode,0)      KolCode   ,ISNULL(MoeenCode,0) Moeencode,
																ISNULL(AccTafID4,0) AcctafID4 ,ISNULL(AccTafID5,0)    AccTafID5 ,ISNULL(AccTafID6,0) AcctafID6,
																PeriodNo                      ,ISNULL(DebitCirculation     ,0) 
																															 /*CASE WHEN @AccAmountDisPlayNature = 1 THEN ISNULL(RemainAmount     ,0)
																																		WHEN @AccAmountDisPlayNature = 2 THEN ISNULL(DebitCirculation ,0)
																																		WHEN @AccAmountDisPlayNature = 3 THEN ISNULL(CreditCirculation,0)
																															 END*/  CT   
												FROM #Comparative 
												) TA10
									WHERE TA10.Groupcode        =  ISNULL(#Comparative.GroupCode   ,0)
												AND 
												TA10.KolCode          =  ISNULL(#Comparative.KolCode     ,0)
												AND 
												TA10.Moeencode        =  ISNULL(#Comparative.MoeenCode   ,0)
												AND 
												TA10.AcctafID4        =  ISNULL(#Comparative.AccTafID4   ,0)
												AND 
												TA10.AccTafID5        =  ISNULL(#Comparative.AccTafID5   ,0) 
												AND 
												TA10.AccTafID6        =  ISNULL(#Comparative.AccTafID6   ,0)
												AND 
												#Comparative.PeriodNo =  TA10.PeriodNo - 1 
									UPDATE #Comparative SET GrowthRate = ISNULL(DebitCirculation     ,0) * 1 WHERE GrowthRate IS NULL 
							END 
							------------------------------------------------------------------------------------- 
								IF @AccAmountDisPlayNature			= 3 -- 1 = Remain Kind  , 2 = Debit Circulation Kind  , 3= CreditcirculationKind 
							 BEGIN 
									UPDATE #Comparative 
									SET GrowthRate = ISNULL(CT,0) /CASE WHEN  ISNULL(CreditCirculation,0)  = 0 THEN 1 ELSE ISNULL(CreditCirculation,0) END 
									FROM (
												SELECT ISNULL(GroupCode,0) Groupcode  ,ISNULL(KolCode,0)      KolCode   ,ISNULL(MoeenCode,0) Moeencode,
																ISNULL(AccTafID4,0) AcctafID4 ,ISNULL(AccTafID5,0)    AccTafID5 ,ISNULL(AccTafID6,0) AcctafID6,
																PeriodNo                      ,ISNULL(CreditCirculation ,0) 
																															 /*CASE WHEN @AccAmountDisPlayNature = 1 THEN ISNULL(RemainAmount     ,0)
																																		WHEN @AccAmountDisPlayNature = 2 THEN ISNULL(DebitCirculation ,0)
																																		WHEN @AccAmountDisPlayNature = 3 THEN ISNULL(CreditCirculation,0)
																															 END*/  CT   
												FROM #Comparative 
												) TA10
									WHERE TA10.Groupcode        =  ISNULL(#Comparative.GroupCode   ,0)
												AND 
												TA10.KolCode          =  ISNULL(#Comparative.KolCode     ,0)
												AND 
												TA10.Moeencode        =  ISNULL(#Comparative.MoeenCode   ,0)
												AND 
												TA10.AcctafID4        =  ISNULL(#Comparative.AccTafID4   ,0)
												AND 
												TA10.AccTafID5        =  ISNULL(#Comparative.AccTafID5   ,0) 
												AND 
												TA10.AccTafID6        =  ISNULL(#Comparative.AccTafID6   ,0)
												AND 
												#Comparative.PeriodNo =  TA10.PeriodNo - 1 
									UPDATE #Comparative SET GrowthRate = ISNULL(CreditCirculation     ,0) * 1 WHERE GrowthRate IS NULL 
							END 
							------------------------------------------------------------------------------------- 
					END 
	  END 

	-----------------------------------------------------------------------
	--SELECT * FROM @CodingList
  --SELECT 2b , * FROM #Comparative
	--------------------------------------------------
		DECLARE @Columns     AS NVARCHAR(MAX),--@Col2 NVARCHAR(MAX),
						@FinalQuery  AS NVARCHAR(MAX)--,@Q NVARCHAR(MAX)

  
		SET  @Columns = STUFF((SELECT ',' + QUOTENAME(PeriodName) 
													 FROM @TimeInterval
													 GROUP  BY PeriodNo,PeriodName
													 ORDER  BY PeriodNo
													 FOR XML PATH(''), TYPE
												 ).value('.', 'NVARCHAR(MAX)') 
											   ,1,1,''
											  )
	 ----------------------------------------
	 
			 IF @AccAmountDisPlayNature	 = 1 
			 BEGIN
				 SET @FinalQuery = 
								'SELECT GroupCode,GroupName,KolCode,KolName , MoeenCode,MoeenName , AccTafID4,AccTafsilName4,AccTafID5,AccTafsilName5,AccTafID6,AccTafsilName6,' + @Columns + ' FROM 
												 (
													SELECT GroupCode,GroupName ,KolCode,KolName, MoeenCode,MoeenName , AccTafID4,AccTafsilName4,AccTafID5,AccTafsilName5,PeriodName,AccTafID6,AccTafsilName6,RemainAmount
													 FROM #Comparative 
												) T
												pivot 
												(
												SUM(RemainAmount)
												FOR PeriodName in (' + @Columns + ') 
												) p
									'
					 --SELECT * FROM ##New_table 			
			 END 
			 ELSE IF @AccAmountDisPlayNature	 = 2
			 BEGIN 
					 SET @FinalQuery = 
								 'SELECT GroupCode,GroupName,KolCode,KolName , MoeenCode,MoeenName , AccTafID4,AccTafsilName4,AccTafID5,AccTafsilName5,AccTafID6,AccTafsilName6,' + @Columns + ' FROM 
								 (
										select GroupCode,GroupName ,KolCode,KolName, MoeenCode,MoeenName , AccTafID4,AccTafsilName4,AccTafID5,AccTafsilName5,PeriodName,AccTafID6,AccTafsilName6, DebitCirculation
										from #Comparative 
								) T
								pivot 
								(
										sum(DebitCirculation)
										for  PeriodName in (' + @Columns + ')
								) p '
								------------------------
						
								/* SET @Q = 
								 'SELECT RowNo ,GroupCode,GroupName,KolCode,KolName , MoeenCode,MoeenName , AccTafID4,AccTafsilName4,AccTafID5,AccTafsilName5,AccTafID6,AccTafsilName6,' + @Col2 + ' FROM 
								 (
										select RowNo,GroupCode,GroupName ,KolCode,KolName, MoeenCode,MoeenName , AccTafID4,AccTafsilName4,AccTafID5,AccTafsilName5,PeriodNo,AccTafID6,AccTafsilName6, DebitCirculation
										from #Comparative 
								) T
								pivot 
								(
										sum(DebitCirculation)
										for  cast(PeriodNo as nvarchar(10)) in (' + @Col2 + ')
								) p '*/
						--PRINT @FinalQuery PRINT @Q --**==
			 END 
			 ELSE IF @AccAmountDisPlayNature	 = 3
			 BEGIN 
					 SET @FinalQuery = 
								 'SELECT GroupCode,GroupName,KolCode,KolName , MoeenCode,MoeenName , AccTafID4,AccTafsilName4,AccTafID5,AccTafsilName5,AccTafID6,AccTafsilName6,' + @Columns + ' FROM 
								 (
										select GroupCode,GroupName ,KolCode,KolName, MoeenCode,MoeenName , AccTafID4,AccTafsilName4,AccTafID5,AccTafsilName5,PeriodName,AccTafID6,AccTafsilName6, CreditCirculation
										from #Comparative 
								) T
								pivot 
								(
										sum(CreditCirculation)
										for PeriodName in (' + @Columns + ')
								) p '
			 END
------------------------------------------------
    
	   INSERT INTO #AnalyzeTbl
	   EXECUTE (@FinalQuery);
		
	 -----------------------------------------
	   ALTER TABLE #AnalyzeTbl  ADD RowNo  SMALLINT 
	  ------------------------------------------------------------
		 
		    UPDATE #AnalyzeTbl 
		    SET RowNo =  RN FROM 
		                    (SELECT ROW_NUMBER() OVER 
																							 (PARTITION BY 
																														CASE  WHEN @P1     = 1 THEN GroupCode WHEN @P1     = 2 THEN KolCode   
																																	WHEN @P1     = 3 THEN MoeenCode WHEN @P1     = 4 THEN AccTafID4
																																	WHEN @P1     = 5 THEN AccTafID5 WHEN @P1     = 6 THEN AccTafID6
												                                    END  
														                     --------------------------------------------------------
																														,CASE WHEN @P2     = 1 THEN GroupCode WHEN @P2      = 2 THEN KolCode
																																	WHEN @P2     = 3 THEN MoeenCode WHEN @P2      = 4 THEN AccTafID4
									 																								WHEN @P2     = 5 THEN AccTafID5 WHEN @P2      = 6 THEN AccTafID6
																														END  
																																--------------------------------------------------------
																													,CASE WHEN @P3     = 1 THEN GroupCode WHEN @P3     = 2 THEN KolCode
																																WHEN @P3     = 3 THEN MoeenCode WHEN @P3     = 4 THEN AccTafID4
									 																							WHEN @P3     = 5 THEN AccTafID5 WHEN @P3     = 6 THEN AccTafID6
																												  	END  
																															--------------------------------------------------------
																													,CASE WHEN @P4		 = 1 THEN GroupCode WHEN @P4		 = 2 THEN KolCode 
																																WHEN @P4     = 3 THEN MoeenCode WHEN @P4     = 4 THEN AccTafID4
									 																							WHEN @P4     = 5 THEN AccTafID5 WHEN @P4		 = 6 THEN AccTafID6
																													 END 
																													--------------------------------------------------------
																													,CASE WHEN @P5		 = 1 THEN GroupCode WHEN @P5		 = 2 THEN KolCode
																																WHEN @P5		 = 3 THEN MoeenCode WHEN @P5		 = 4 THEN AccTafID4
									 																							WHEN @P5		 = 5 THEN AccTafID5 WHEN @P5		 = 6 THEN AccTafID6
																													 END  
																													--------------------------------------------------------
																													,CASE WHEN @P6		 = 1 THEN GroupCode WHEN @P6     = 2 THEN KolCode 
																																WHEN @P6		 = 3 THEN MoeenCode WHEN @P6     = 4 THEN AccTafID4
									 																							WHEN @P6		 = 5 THEN AccTafID5 WHEN @P6		 = 6 THEN AccTafID6
																													 END     
																									ORDER BY 
																													CASE  WHEN @P1     = 1 THEN GroupCode WHEN @P1     = 2 THEN KolCode   
																																WHEN @P1     = 3 THEN MoeenCode WHEN @P1     = 4 THEN AccTafID4
																																WHEN @P1     = 5 THEN AccTafID5 WHEN @P1     = 6 THEN AccTafID6
												                                    END  
														                     --------------------------------------------------------
																														,CASE WHEN @P2     = 1 THEN GroupCode WHEN @P2      = 2 THEN KolCode
																																	WHEN @P2     = 3 THEN MoeenCode WHEN @P2      = 4 THEN AccTafID4
									 																								WHEN @P2     = 5 THEN AccTafID5 WHEN @P2      = 6 THEN AccTafID6
																														 END  
																																--------------------------------------------------------
																													, CASE WHEN @P3     = 1 THEN GroupCode WHEN @P3     = 2 THEN KolCode
																																 WHEN @P3     = 3 THEN MoeenCode WHEN @P3     = 4 THEN AccTafID4
									 																							 WHEN @P3     = 5 THEN AccTafID5 WHEN @P3     = 6 THEN AccTafID6
																												  	END  
																															--------------------------------------------------------
																													,CASE WHEN @P4		 = 1 THEN GroupCode WHEN @P4		 = 2 THEN KolCode 
																																WHEN @P4     = 3 THEN MoeenCode WHEN @P4     = 4 THEN AccTafID4
									 																							WHEN @P4     = 5 THEN AccTafID5 WHEN @P4		 = 6 THEN AccTafID6
																													 END 
																													--------------------------------------------------------
																													,CASE WHEN @P5		 = 1 THEN GroupCode WHEN @P5		 = 2 THEN KolCode
																																WHEN @P5		 = 3 THEN MoeenCode WHEN @P5		 = 4 THEN AccTafID4
									 																							WHEN @P5		 = 5 THEN AccTafID5 WHEN @P5		 = 6 THEN AccTafID6
																													 END  
																													--------------------------------------------------------
																													,CASE WHEN @P6		 = 1 THEN GroupCode WHEN @P6     = 2 THEN KolCode 
																																WHEN @P6		 = 3 THEN MoeenCode WHEN @P6     = 4 THEN AccTafID4
									 																							WHEN @P6		 = 5 THEN AccTafID5 WHEN @P6		 = 6 THEN AccTafID6
																													 END     
																							)RN , GroupCode,KolCode,MoeenCode,AccTafID4,AccTafID5 , AccTafID6
																	FROM #AnalyzeTbl
																)  TA10
								WHERE ISNULL(TA10.GroupCode,0) =ISNULL(#AnalyzeTbl.GroupCode,0)
								      AND 
											ISNULL(TA10.KolCode,0) =ISNULL(#AnalyzeTbl.KolCode,0)
											AND 
											ISNULL(TA10.MoeenCode,0) =ISNULL(#AnalyzeTbl.MoeenCode,0)
											AND 
											ISNULL(TA10.AccTafID4,0) =ISNULL(#AnalyzeTbl.AccTafID4,0)
											AND
                      ISNULL(TA10.AccTafID5,0) =ISNULL(#AnalyzeTbl.AccTafID5,0)
											AND 
											ISNULL(TA10.AccTafID6,0) =ISNULL(#AnalyzeTbl.AccTafID6,0)
	  --------------------------------------------------------------
		 IF @ReportNature = 2 
		 BEGIN
			  DECLARE @AnalyticalQuery  NVARCHAR(MAX)
			  ;WITH AnalyzeColumns 
				AS(
						SELECT T2.ColumnName                + ' - ' + T1.ColumnName   AS Conflict,
									 'CAST(('+ T2.ColumnName      + ' - ' + T1.ColumnName +') / '+' CASE WHEN  ISNULL( '+ T1.ColumnName + ',0)  = 0 THEN 1 ELSE ISNULL( '+T1.ColumnName +',0) END AS NVARCHAR(50))'  AS RatioOfChange,
									 'CAST('+T2.ColumnName        + ' / ' + ' CASE WHEN  ISNULL( '+ T1.ColumnName + ',0)  = 0 THEN 1 ELSE ISNULL( '+T1.ColumnName +',0) END AS NVARCHAR(50))'  AS GrowthRate,
									 T1.ColumnName Col1, T2.ColumnName              AS Col2
						FROM   @ColList T1 
									 INNER JOIN @ColList AS T2 ON T1.ColumnID = T2.ColumnID - 1
						WHERE T1.ColumnID > 12
					)
					SELECT @AnalyticalQuery = 
					(
					 SELECT 'SELECT RowNo,  CAST(GroupCode AS NVARCHAR(50)) GroupCode ,GroupName, CAST(KolCode AS NVARCHAR(50)) KolCode ,KolName,CAST(MoeenCode AS NVARCHAR(50))MooenCode ,
					         MoeenName   , CAST (AccTafID4 AS NVARCHAR(50)) AccTafID4 ,AccTafsilName4,CAST(AccTafID5 AS NVARCHAR(50)) AccTafID5 ,AccTafsilName5,CAST(AccTafID6  AS NVARCHAR(50)) AccTafID6,
									 AccTafsilName6, ' +
														STUFF(
																	(SELECT  
																				',[' + Col1 + '],[' + Col2 + '],' +
																				 CAST(Conflict   AS NVARCHAR(50))     + ' AS [مغایرت '      + Col1 + ' و '   + Col2  + '],'+
																				 RatioOfChange                        + ' AS [نسبت تغییر '   + Col1 + ' به '  + Col2  + '],'+
																				 AnalyzeColumns.GrowthRate            + ' AS [نرخ رشد '     + Col1 + ' به '  + Col2  + ']'
																	 FROM  AnalyzeColumns
																	 FOR XML PATH('')
																	)
																	, 1,1,''
																)	+' FROM #AnalyzeTbl '
					)
		  	--SELECT @AnalyticalQuery--**==
				
				EXEC(@AnalyticalQuery)
				
			-------------------------------------
			IF @ConflictOfTwoPeriods = 1 
			BEGIN
				INSERT INTO @ColList ( ColumnID,ColumnName)
				SELECT T2.ColumnID+.1,'مغایرت '      + T1.ColumnName + ' و '   + T2.ColumnName  + '' ColumnName 
				FROM   @ColList T1 
									 INNER JOIN @ColList AS T2 ON T1.ColumnID = T2.ColumnID - 1
						
				WHERE T2.ColumnID > 13 AND T1.ColumnID <> (SELECT MAX(ColumnID) FROM @ColList)
				      AND (T1.ColumnID % CAST(T1.ColumnID AS INTEGER) ) = 0 
						  AND(T2.ColumnID % CAST(T2.ColumnID AS INTEGER) ) = 0
			END 
		 ----------------------------------------------
		 IF @RatioOfChange = 1 
		 BEGIN 
		    INSERT INTO @ColList ( ColumnID,ColumnName)
				SELECT T2.ColumnID+.2,'نسبت تغییر '   + T1.ColumnName + ' به '  + T2.ColumnName   ColumnName 
				FROM   @ColList T1 
									 INNER JOIN @ColList AS T2 ON T1.ColumnID = T2.ColumnID - 1
						
				WHERE T2.ColumnID > 13 AND T1.ColumnID <> (SELECT MAX(ColumnID) FROM @ColList)
				      AND (T1.ColumnID % CAST(T1.ColumnID AS INTEGER) ) = 0 
					    AND(T2.ColumnID % CAST(T2.ColumnID AS INTEGER) ) = 0 
			END 
			-----------------------------------------
			IF @GrowthRate = 1 
			BEGIN 
				  INSERT INTO @ColList ( ColumnID,ColumnName)
			    SELECT T2.ColumnID+.1,'نرخ رشد '     + T1.ColumnName + ' به '  + T2.ColumnName   ColumnName 
				  FROM   @ColList T1 
									 INNER JOIN @ColList AS T2 ON T1.ColumnID = T2.ColumnID - 1
						
				  WHERE T2.ColumnID > 13 AND T1.ColumnID <> (SELECT MAX(ColumnID) FROM @ColList)
				         AND (T1.ColumnID % CAST(T1.ColumnID AS INTEGER) ) = 0 
						    AND(T2.ColumnID % CAST(T2.ColumnID AS INTEGER) ) = 0 
			END 
			-----------------------------------------
			----------------------------------------
			 INSERT INTO @ColList ( ColumnID,ColumnName)
			 SELECT ColumnID+.4,ColumnName FROM @ColList
				WHERE ColumnID > 13 AND ColumnID <> (SELECT MAX(ColumnID) FROM @ColList)
				      AND (ColumnID % CAST(ColumnID AS INTEGER) ) = 0 
			-----------------------------------------
			 SELECT * FROM @ColList ORDER BY ColumnID  ASC 
				
		END -- IF @ReportNature = 2  Analytical State
    ELSE IF @ReportNature = 1 -- Simple State 
		BEGIN 
				SELECT * FROM #AnalyzeTbl 
				SELECT * FROM @ColList
		END 

	 --SELECT * FROM #AnalyzeTbl2 --**==

	
	 --EXEC (' SELECT * FROM #New_table ')
	 --------------------------
	/* IF @ReportNature =2 
	 BEGIN
	    SET @IntervalRow = 12 SET @MaxInterval = (SELECT ISNULL(MAX(PeriodNo),0) FROM @TimeInterval)
				--SELECT @MaxInterval --**== 
				WHILE @IntervalRow <= @MaxInterval
				BEGIN 
				   SET @ColName          = (SELECT 'Conflict'+CAST(@IntervalRow AS NVARCHAR(10))+'With'+CAST(@IntervalRow+1 AS NVARCHAR(10)) )
				--	 SELECT @ColName--**==
					 SET @AddCol           = 'ALTER TABLE #AnalyzeTbl ADD   '+ CAST(@ColName AS NVARCHAR(50)) +'  DECIMAL(26,6) '
					 EXEC (@AddCol)
					 ---------------------------------------------------
					  SET @AddCol           = 'ALTER TABLE #AnalyzeTbl2 ADD   '+ CAST(@ColName AS NVARCHAR(50)) +'  DECIMAL(26,6) '
						EXEC (@AddCol)
						---------------------------------------------------
				
					 SET @IntervalRow = @IntervalRow+1  
				END 
	 END */
	--SELECT * FROM #AnalyzeTbl

   IF ( SELECT COUNT(*)  from  @AccPriority) =0
	 BEGIN 
		    INSERT INTO @AccPriority  (RowNo,AccKind,AccKindCodeName,AccKindName )
			  VALUES                    (1,3,'MoeenCode', 'MoeenName')
	 END
	 IF @DelRow IS NOT NULL 
				INSERT INTO @AccPriority
		               ( RowNo     , AccKind , AccKindCodeName , AccKindName)
 	      VALUES     ( @MaxRow   , @DelRow , @DelRowKindName , @DelRowName)
		SELECT * FROM @AccPriority
	------------------------------------------------
--	  SELECT * FROM @TimeInterval
	-------------------------------------------------
						--WHERE T1.ColumnID > 12
		-----------------------------------------------
		DROP TABLE #CodingList 
		DROP TABLE #Comparative
		IF OBJECT_ID('tempdb..#New_table') IS NOT NULL
	    DROP TABLE #New_table
    IF OBJECT_ID('tempdb..#AnalyzeTbl') IS NOT NULL
      DROP TABLE #AnalyzeTbl
		IF OBJECT_ID('tempdb..#AnalyzeTbl2') IS NOT NULL
      DROP TABLE #AnalyzeTbl2
END

