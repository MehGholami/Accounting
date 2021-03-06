USE [TavanaR2]
GO
/****** Object:  StoredProcedure [dbo].[RepAccAnalyze]    Script Date: 3/15/2022 9:12:43 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER  PROCEDURE [dbo].[RepAccAnalyze]
	-- Add the parameters for the stored procedure here
	@FinancialPeriodIDFrom             SMALLINT				       ,-- از دوره مالی 
	@FinancialPeriodIDTo               SMALLINT			         ,-- تا دوره مالی 
	@AccDocStateList									 NVARCHAR(50)   = NULL ,-- وضعیت سند 
	@AccDocKindList			               NVARCHAR(1000)	= NULL ,-- نوع سند 
	@TafGrpIDList                      NVARCHAR(500)  = NULL ,-- '45,6,7,8,454,45'
	@ReportKind                        TINYINT               ,--  1 = Date    , 2 = Monthly  
	@MonthFrom  										   TINYINT        = NULL ,--  Only Monthly Kind Report
	@YearFrom                          SMALLINT				= NULL ,--  Only Monthly Kind Report
	@MonthTo                           TINYINT        = NULL ,--  Only Monthly Kind Report		
	@YearTo												     SMALLINT       = NULL ,--  Only Monthly Kind Report
	@DateFrom													 DATE           = NULL ,--  Only Date    Kind Report
	@DateTo														 DATE           = NULL ,--  Only Date    Kind Report
	@AccType                           TINYINT        = NULL ,--  نوع حساب   
	@MoeenCode												 BIGINT         = NULL ,-- کد معیین 
	@AccTafID													 BIGINT         = NULL ,-- کد تفصیلی
	@AllItems													 BIT            = NULL ,-- همه اقلام
	@UsrPayRow                         INT                   ,
	@MatchList								         NVARCHAR(MAX)  = NULL ,-- JSON Match List  لیست تطبیق'[ {"DtlID":"15646",	"DtlAmnt":"45841000" },{"DtlID":"45411",	"DtlAmnt":"4500000" }]'
	@BranchCode												 INT		        = NULL ,-- شعبه 
	@AnalyzeType											 TINYINT        = 1    ,-- 1 = Account (With MoeenCode) , 2 = Tafsil (With TafsilCode)
	@MatchedItems											 BIT            = NULL ,-- اقلام تطبیق شده 
	@UnMatchedItems										 BIT            = 1    ,-- اقلام تطبیق نشده
	@CurrencyIDList										 NVARCHAR(100)  = NULL ,-- لیست شناسه ارزها 
	@BranchCodeList                    VARCHAR(500)   = NULL ,-- لیست شعب 
	@AccTafLevelList                   VARCHAR(10)    = NULL , -- تعیین سطوح تفصیلی  
	@CurrencyProperty                  TINYINT        = 0     -- 0 = None Currency      , 1 = Currency 
	

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	  BEGIN TRY 
		     BEGIN TRAN  RepAnlyze
				       DECLARE @TErrMsg           NVARCHAR(200)
							 --SELECT * FROM  dbo.AccAnalyze
							 /* @MatchList   JSON 
	               '[ {"DtlID":"15646",	"DtlAmnt":"45841000" },{"DtlID":"45411",	"DtlAmnt":"4500000" }]'
	             */
							 --------------------------------------------------------				
		           DECLARE @AccMatchList   TABLE (AccDocDTLID   BIGINT       , AccAnlayzeAmount DECIMAL(26,6) ,AccDocDTLAmount    DECIMAL(26,6) ,
							                                MatchedAmount DECIMAL(26,6), AvailableAmount  DECIMAL(26,6) ,DebitCreditDlag    BIT  
																						 )
								------------------------------------------------------------------------------
								DECLARE @TafLevelList    TABLE (AccTafLevel   TINYINT ) 
								
								IF @AccTafLevelList  IS NOT NULL 
								BEGIN 
								   INSERT INTO @TafLevelList (AccTafLevel )
								   SELECT * FROM dbo.Split   (@AccTafLevelList , ',')
								END 
							  --------------------------------------حذف ردیف های نامعتبر -------------------   
								DELETE FROM dbo.AccAnalyze
								WHERE  DebitAccDocDTLID IN (SELECT DebitAccDocDTLID
							                              FROM dbo.AccAnalyze   
													                      INNER JOIN dbo.AccDocDetail ON AccDocDtlID = DebitAccDocDTLID
 													                  WHERE DebitCreditFlag = 0 
																					)
							 ---------------------------------------------------------
							  DELETE FROM dbo.AccAnalyze
							  WHERE  CreditAccDocDTLID IN (SELECT CreditAccDocDTLID
							                              FROM dbo.AccAnalyze   
													                      INNER JOIN dbo.AccDocDetail ON AccDocDtlID = DebitAccDocDTLID
 													                  WHERE DebitCreditFlag = 1 
																						)
							 
							
							 -----------------------======================================================================---------------------------------
							 IF @MatchList IS NOT NULL
							 BEGIN 
							     INSERT INTO @AccMatchList  ( AccDocDTLID , AccAnlayzeAmount )
							     SELECT                       DTLID       , DtlAmnt
									 FROM OPENJSON (@MatchList)
									 WITH ( DtlID  BIGINT , DtlAmnt  DECIMAL(26,6)) L
									 ------------------------------------------------
									 IF  ( SELECT COUNT(*)
									             FROM (
									 									  SELECT DebitCreditFlag
									                    FROM  dbo.AccDocDetail
															              INNER JOIN @AccMatchList ON [@AccMatchList].AccDocDTLID = AccDocDetail.AccDocDtlID
															        GROUP BY DebitCreditFlag 
																		)T
											  )<>2
									 BEGIN 
									     RAISERROR (' برای انجام تطبیق حداقل باید دو قلم نوع گردش متفاوت داشته باشند  ',18,1)
									 END
									 --------------------------------------------------------------------------
									 IF  EXISTS (SELECT [@AccMatchList].AccDocDTLID
									             FROM  dbo.AccDocDetail
															       RIGHT  JOIN @AccMatchList ON [@AccMatchList].AccDocDTLID = AccDocDetail.AccDocDtlID
																		 WHERE AccDocDetail.AccDocDtlID IS NULL 
															)
									 BEGIN 
										    RAISERROR(' برخی از اقلام تطبیقی معتبر نمی باشد  ',18,1)
									 END 
										---------------------------------------------------------------------------
										---------------------------------------------------------------------------
									 UPDATE @AccMatchList SET 
										                        MatchedAmount = MAmnt ,AccDocDTLAmount = ADAmnt , DebitCreditDlag = DCF
									 FROM (
											    SELECT  AccDocDtlID , CASE WHEN DebitCreditFlag = 1   THEN T1.MatchedDebit
													                           WHEN DebitCreditFlag = 0   THEN T2.MatchedCredit
																										 ELSE 0 END   MAmnt ,
																  AccDocDtlAmount ADAmnt , DebitCreditFlag DCF
								       
																	       
											    FROM   dbo.AccDoc
														     INNER JOIN  dbo.AccDocDetail    ON AccDocDetail.AccDocID				= AccDoc.AccDocId
														
																LEFT  JOIN  
																					( SELECT   D1.DebitAccDocDTLID , ISNULL(SUM(D1.AnalyzeAmount),0) MatchedDebit 
																					  FROM     dbo.AccAnalyze D1  
																						GROUP BY D1.DebitAccDocDTLID
																					)T1
																					ON T1.DebitAccDocDTLID	 = dbo.AccDocDetail.AccDocDtlID
																						AND ((DebitCreditFlag  = 1 AND T1.DebitAccDocDTLID IS NOT NULL ) OR T1.DebitAccDocDTLID IS NULL )
																
																LEFT  JOIN  
																					( SELECT   C1.CreditAccDocDTLID , ISNULL(SUM(C1.AnalyzeAmount),0) MatchedCredit 
																					  FROM     dbo.AccAnalyze C1
																						GROUP BY C1.CreditAccDocDTLID
																					)T2
																					ON T2.CreditAccDocDTLID  = dbo.AccDocDetail.AccDocDtlID
																						 AND ((DebitCreditFlag = 0 AND  T2.CreditAccDocDTLID IS NOT NULL ) OR T2.CreditAccDocDTLID IS NULL )
																				
									         WHERE AccDocState <>0  
													     	AND 
														    AccDocDtlID IN (SELECT AccDocDTLID FROM  @AccMatchList)
												)T3
                   WHERE T3.AccDocDTLID = [@AccMatchList].AccDocDTLID
									--------------------------------------------------------
							     IF  (SELECT MAX(RowNo) 
									      FROM (SELECT ROW_NUMBER() OVER (PARTITION BY TA.TotAnlyzeAmount ORDER BY TA.TotAnlyzeAmount ) RowNo
															FROM (
																		  SELECT   DebitCreditDlag , SUM(AccAnlayzeAmount) TotAnlyzeAmount   
									                    FROM @AccMatchList
									                    GROUP BY DebitCreditDlag
																		)TA 
															)TA2
												)=1
									  BEGIN 
										    RAISERROR (' جمع اقلام بدهکار و بستانکار انالیز برابر نیست  ',18,1)
										END 

									--------------------------------------------------------------------------------------
									  UPDATE @AccMatchList SET AvailableAmount = AccDocDTLAmount - ISNULL(MatchedAmount,0) 
									--------------------------------------------------------
										IF EXISTS (SELECT * FROM @AccMatchList WHERE AvailableAmount<=0)
										BEGIN 
												RAISERROR(' مبلغ تطبیق شده از مبلغ قابل تخصیص تجاوز می کند  ',18,1)
										END 
										-----------------------------------------------------------------------------------
										------------------------- INSERT INTO AccAnalyze Table ----------------------------
										INSERT INTO dbo.AccAnalyze
										          ( DebitAccDocDTLID, CreditAccDocDTLID,  AnalyzeAmount, UsrPayRow)
										SELECT     CASE WHEN DebitCreditFlag = 1 THEN [@AccMatchList].AccDocDTLID ELSE NULL END  , 
										           CASE WHEN DebitCreditFlag = 0 THEN [@AccMatchList].AccDocDTLID ELSE NULL END  ,
															 AccAnlayzeAmount , @UsrPayRow
										        
										        
										FROM   @AccMatchList
										       INNER JOIN dbo.AccDocDetail ON AccDocDetail.AccDocDtlID = [@AccMatchList].AccDocDTLID
													 INNER JOIN dbo.VWAccMTList  ON VWAccMTList.AccMTMapID   = AccDocDetail.AccMTMapID 

							 END -- IF @MatchList IS NOT NULL
							 --------------------===============================================================================----------------------------
							 DECLARE    
													@AccDocKindList_ALL              BIT = 0,
													@AccDocStateList_ALL             BIT = 0,
													@CurrencyProperty_ALL            BIT = 0,
													@CurrencyIDList_ALL              BIT = 0,
													@BranchCodeList_All              BIT = 0,
													@MatchedItems_ALL								 BIT = 0,-- اقلام تطبیق شده 
	                        @UnMatchedItems_ALL							 BIT = 0 -- اقلام تطبیق نشده
							------------------------------------------------------
								IF @AccDocKindList       IS NOT NULL SET @AccDocKindList_ALL		 = 1;
								IF @AccDocStateList      IS NOT NULL SET @AccDocStateList_ALL		 = 1;
			          IF @CurrencyProperty     IS NOT NULL SET @CurrencyProperty_ALL	 = 1;
			          IF @CurrencyIDList       IS NOT NULL SET @CurrencyIDList_ALL		 = 1;
			          IF @MatchedItems_ALL     IS NOT NULL SET @MatchedItems_ALL       = 1;
								IF @UnMatchedItems_ALL   IS NOT NULL SET @UnMatchedItems_ALL     = 1;
										
							------------------------------------------------------
							 DECLARE @AccDockind     TABLE (AccdocKindCode    INT )
							-----------------------------------------------------
							 DECLARE @AccDocState    TABLE (DocStateID        INT ) 
							 ------------------------------------------------------
							 DECLARE @BranchList     TABLE (BrchCode          INT )
							 -------------------------------------------------------		
							 DECLARE @CurrencyList   TABLE (CurrencyID        INT )	
							 -------------------------------------------------------
            	 DECLARE  @StartFinanAllocate   SMALLINT     , @EndFinanAllocate   SMALLINT 
			        --------------------------------------------------------
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
							----------------------------------------------------------------------------------------------------------------------------------------------
		
							SET @StartFinanAllocate = (SELECT  FinancialAllocateID      FROM dbo.FinancialAllocate  WHERE KolNotBookID      = 1 AND FinancialPeriodID = @FinancialPeriodIDFrom   )												  
							SET @EndFinanAllocate   = (SELECT  FinancialAllocateID      FROM dbo.FinancialAllocate  WHERE KolNotBookID      = 1 AND FinancialPeriodID = @FinancialPeriodIDTo     )												  
							-----------------------------------------------------------------
								IF @FinancialPeriodIDFrom NOT IN ( SELECT FinancialPeriodID FROM  dbo.FinancialPeriod)
									OR 
									@FinancialPeriodIDTo   NOT IN ( SELECT FinancialPeriodID FROM  dbo.FinancialPeriod)
								BEGIN 
										RAISERROR (' شناسه ((دوره مالي  )) نامعتبر است  ',18,1)
								END 
         -------------------------------------------------------------------------------------------------
				        IF @ReportKind = 2 -- Monthly 
			          BEGIN 
			    					EXEC dbo.DateInterval
																				@YearFrom                 ,--@YearFrom = 0,                -- int
			   																@MonthFrom                ,--@MonthFrom = 0,               -- int
			   																@YearTo                   ,--@YearTo = 0,                  -- int
			   																@MonthTo                  ,--@MonthTo = 0,                 -- int
			   																@DateFrom     OUTPUT      ,--@DateFrom = @DateFrom OUTPUT, -- date
			   																@DateTo       OUTPUT       --@DateTo = @DateTo OUTPUT      -- date	 	         	  	
					----------------------------------------------------------------------------------------
										IF @DateFrom < (SELECT FinancialAllocateStartDate FROM dbo.FinancialAllocate  
																			WHERE  FinancialAllocateID = @StartFinanAllocate
																		 )
											 OR 
											 @DateFrom > (SELECT FinancialAllocateEndDate FROM dbo.FinancialAllocate  
																		 WHERE FinancialAllocateID = @EndFinanAllocate
																		)
											BEGIN 
													 RAISERROR (' شروع  ماه و سال ها در محدوده دوره مالي وارده نيست ',18,1)
											END 
			   	---------------------------------------------------------------------------------------- 
					 						IF @DateFrom < (SELECT FinancialAllocateStartDate FROM dbo.FinancialAllocate  
																				WHERE  FinancialAllocateID = @StartFinanAllocate
																			 )
												 OR 
												 @DateTo > (SELECT FinancialAllocateEndDate FROM dbo.FinancialAllocate  
																		 WHERE FinancialAllocateID = @EndFinanAllocate
																		)
											BEGIN 
													 RAISERROR ('  پايان ماه و سال ها در محدوده دوره مالي وارده نيست ',18,1)
											END

							------------------------------------------------------------
			          END -- SELECT * FROM dbo.AccAnalyze
								----------------------------------------------------------------------------------------
								SELECT AccDocDetail.AccMTMapID , AccDocDtlID , Branches.BranchCode, BrchName BranchName , 
								       AccDocReferNo           , AccDocDate  , AccDocDtlDesc      , CASE WHEN DebitCreditFlag = 1 THEN AccDocDtlAmount ELSE NULL  END  ,
											 CASE WHEN DebitCreditFlag = 0 THEN AccDocDtlAmount ELSE NULL  END  ,
											 CASE WHEN DebitCreditFlag = 1 THEN AccDocDtlAmount ELSE 0  END  - T1.MatchedDebit   NoMatchedDebit,
											 CASE WHEN DebitCreditFlag = 0 THEN AccDocDtlAmount ELSE 0  END  - T2.MatchedCredit  NoMatchedCredit ,
											 T1.MatchedDebit , T2.MatchedCredit 
								       
																	       
							  FROM   dbo.AccDoc
								      INNER JOIN  dbo.Branches        ON Branches.BranchCode          = AccDoc.BranchCode
											INNER JOIN  dbo.AccDocDetail    ON AccDocDetail.AccDocID				= AccDoc.AccDocId
											INNER JOIN  dbo.VWAccMTList     ON VWAccMTList.AccMTMapID       = AccDocDetail.AccMTMapID
											
											LEFT  JOIN  
											          ( SELECT D1.DebitAccDocDTLID , ISNULL(SUM(D1.AnalyzeAmount),0) MatchedDebit  FROM      dbo.AccAnalyze D1  
																  GROUP BY D1.DebitAccDocDTLID
											          )T1
											          ON T1.DebitAccDocDTLID	 = dbo.AccDocDetail.AccDocDtlID
											                                     AND ((DebitCreditFlag = 1 AND T1.DebitAccDocDTLID IS NOT NULL ) OR T1.DebitAccDocDTLID IS NULL )
																
											LEFT  JOIN  
											          ( SELECT   C1.CreditAccDocDTLID , ISNULL(SUM(C1.AnalyzeAmount),0) MatchedCredit FROM  dbo.AccAnalyze C1
																  GROUP BY C1.CreditAccDocDTLID
																)T2
																ON T2.CreditAccDocDTLID  = dbo.AccDocDetail.AccDocDtlID
											                                   AND ((DebitCreditFlag = 0 AND  T2.CreditAccDocDTLID IS NOT NULL ) OR T2.CreditAccDocDTLID IS NULL )
																				
								WHERE AccDocState <>0 
											AND 
											(@AccDocKindList_ALL      = 0   OR (AccDocKindCode              IN (SELECT AccdocKindCode FROM @AccDockind )))
											AND 
											(@AccDocStateList_ALL     = 0   OR (AccDoc.AccDocState		      IN (SELECT DocStateID     FROM @AccDocState )))
											AND  
											(@CurrencyIDList_ALL      = 0   OR (AccDocDetail.CurrencyID     IN (SELECT CurrencyID     FROM @CurrencyList)))
											AND 
											(@BranchCodeList_All      = 0   OR (dbo.AccDoc.BranchCode       IN (SELECT Branches.BranchCode     FROM @BranchList  )))
											AND
											CAST(AccDocDate   AS DATE  ) BETWEEN  @DateFrom  AND @DateTo 
											AND 
											((@MoeenCode IS NOT NULL AND   @AccTafID IS NULL   AND MoeenCode =  @MoeenCode  ) OR @MoeenCode IS NULL )
											AND 
											(@MoeenCode  IS NULL AND @AccTafID IS NOT NULL  
											 AND 
											    ( ( AccTafID4 = @AccTafID  AND (@AccTafLevelList IS NULL OR 4 IN (SELECT AccTafLevel FROM @TafLevelList ) ) )
											       OR 
											      (AccTafID5 = @AccTafID   AND (@AccTafLevelList IS NULL OR 5 IN (SELECT AccTafLevel FROM @TafLevelList ) )  )
											       OR   
											      (AccTafID6 = @AccTafID   AND (@AccTafLevelList IS NULL OR 6 IN (SELECT AccTafLevel FROM @TafLevelList ) )  )
											    )
                       )
											 AND 
											 (@MatchedItems_ALL        = 0   OR ((ISNULL(T1.MatchedDebit,0) > 0 OR ISNULL(T2.MatchedCredit,0) > 0) AND @UnMatchedItems_ALL =0 ))
											 AND 
											 (@UnMatchedItems_ALL      = 0   OR ((ISNULL(T1.MatchedDebit,0) = 0 AND  ISNULL(T2.MatchedCredit,0) = 0) AND @MatchedItems_ALL = 0 ))
		     COMMIT TRAN RepAnlyze
		END TRY 
		BEGIN CATCH
          SET @TErrMsg = (SELECT ERROR_MESSAGE())
					ROLLBACK TRAN RepAnlyze 
					RAISERROR (@TErrMsg,18,1)
		END CATCH

END
