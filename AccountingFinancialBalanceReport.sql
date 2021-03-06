USE [TavanaR2]
GO
/****** Object:  StoredProcedure [dbo].[RepAccFinancialBalance]    Script Date: 3/15/2022 9:13:37 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER   PROCEDURE  [dbo].[RepAccFinancialBalance]
	-- Add the parameters for the stored procedure here
	@FinancialPeriodIDFrom             SMALLINT				       ,
	@FinancialPeriodIDTo               SMALLINT							 ,
	@ReportColumnKind                  TINYINT							 , -- WITH These Values 2,4,6,8
	@RemainKind                        TINYINT							 , -- 3 = DebitCredit   , 4 = Debit , 5 = Credit  , 6 = DebitCredit With Zero Value   , 7 = Zero Remain 
	@StartDate                         DATE									 ,
	@EndDate													 DATE									 ,
	@AccDocNoFrom											 BIGINT					= NULL ,
	@AccDocNoTo 											 BIGINT					= NULL ,
	@AccDocKindList			               NVARCHAR(1000)	= NULL ,
	@CurrencyProperty                  TINYINT        = NULL ,-- ویژگی ارزی  
	@CurrencyBase                      TINYINT        = 1    ,--  1 = BasedCurrency  ,2 =  Currency 
	@DisplayRialAmounts                BIT            = 1    ,
	@DisPlayCurrencyAmounts            BIT            = 1    ,
	@DisplayNumericalValues            BIT            = 0    ,
	@AccountsPriorityList              NVARCHAR(MAX)         ,-- 1 = Group , 2 = Kol  , 3 = Moeen And it is Default , 4 =TafLeve4 , 5 = tafLevel5 , 6 = TafLevel6
	@AccountCodeList                   NVARCHAR(MAX)  = NULL ,-- Json For Account Code List 
	@JustNoTafsil                      BIT            = 0    ,
	@PrintInSeparatePage               BIT            = 0    ,
	@WithRemainFromLastYear            BIT            = 0    ,
	@AccActive											   BIT            = 0    ,
	@FollowupProperty                  BIT            = 0    ,
	@CountProperty                     BIT            = NULL ,
 	@AccReferNoFrom										 BIGINT         = NULL ,
	@AccReferNoTo											 BIGINT         = NULL ,
	@AccDocStateList									 NVARCHAR(50)   = NULL ,
	@UsrPayRowList                     NVARCHAR(1000) = NULL ,
	@ReviewUsrPayRowList               NVARCHAR(1000) = NULL ,
	@CurrencyIDList										 NVARCHAR(100)  = NULL ,
	@AmountRemain                      TINYINT        = 1    ,
	@DebitAmountFrom                   DECIMAL(26,6)  = NULL ,
	@DebitAmountTo                     DECIMAL(26,6)  = NULL ,
	@CreditAmountFrom                  DECIMAL(26,6)  = NULL ,
	@CreditAmountTo										 DECIMAL(26,6)  = NULL ,
	@CurrencyRemainKind			           TINYINT        = NULL ,
	@DebitRemainFrom                   DECIMAL(26,6)  = NULL ,
	@DebitRemainTo										 DECIMAL(26,6)  = NULL ,
  @CreditRemainFrom                  DECIMAL(26,6)  = NULL ,
	@CreditRemainTo										 DECIMAL(26,6)  = NULL ,
	@AccDocDesc												 NVARCHAR(1000) = NULL ,
	@TrackingNumber										 BIGINT         = NULL ,
	@TrackingDateFrom									 DATE           = NULL ,
	@TrackingDateTo                    DATE           = NULL ,
	@BranchCodeList                    NVARCHAR(100)  = NULL  -- 4,5,6

	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	 /*
'[ { "AccountsPriorityCode":"3","AccountCodeList":"100014,140025,325001"  },  { "AccountsPriorityCode":"4"	"AccountCodeList":"2530014,3840045,7851012" } ]'
	*/
   /* @AccountsPriorityList
	 '[ {"RowNo":"1"	"AccKind":"3" },{  "RowNo":"2"AccKind":"4" }]'
	 */
	 
	  -- Insert statements for procedure here
		DECLARE       	@AccDocNoFrom_ALL								 BIT = 0,
	                  @AccDocNoTo_ALL								   BIT = 0,
										@AccDocKindList_ALL              BIT = 0,
										@AccReferNoFrom_ALL              BIT = 0,
										@AccReferNoTo_ALL                BIT = 0,
										@AccDocStateList_ALL             BIT = 0,
										@UsrPayRowList_ALL               BIT = 0,
										@ReviewUsrPayRowList_ALL         BIT = 0,
										@CurrencyIDList_ALL              BIT = 0,
										@DebitAmountFrom_ALL             BIT = 0,
										@DebitAmountTo_ALL               BIT = 0,
										@CreditAmountFrom_ALL            BIT = 0,
										@CreditAmountTo_ALL              BIT = 0,
										@AccDocDesc_ALL                  BIT = 0,
										@TrackingNumber_ALL              BIT = 0,
										@BranchCodeList_All              BIT = 0
                    
	  DECLARE         @P1              TINYINT      , @P2  TINYINT     ,@P3  TINYINT     ,@P4  TINYINT     , @P5  TINYINT     , @P6  TINYINT     ,@DelRow           TINYINT    ,@MaxRow    INT ,
		                @PN1					   NVARCHAR(50) , @PN2 NVARCHAR(50),@PN3 NVARCHAR(50),@PN4 NVARCHAR(50), @PN5 NVARCHAR(50), @PN6 NVARCHAR(50),@DelRowName       NVARCHAR(50),
										@DelRowKindName  NVARCHAR(50)
	
		IF @AccDocNoFrom 			  IS NOT NULL SET @AccDocNoFrom_ALL 			 = 1;
		IF @AccDocNoTo			    IS NOT NULL SET @AccDocNoTo_ALL 				 = 1;
		IF @AccDocKindList      IS NOT NULL SET @AccDocKindList_ALL			 = 1;
		IF @AccReferNoFrom      IS NOT NULL SET @AccReferNoFrom_ALL			 = 1;
		IF @AccReferNoTo        IS NOT NULL SET @AccReferNoTo_ALL				 = 1;
		IF @AccDocStateList     IS NOT NULL SET @AccDocStateList_ALL		 = 1;
		IF @UsrPayRowList       IS NOT NULL SET @UsrPayRowList_ALL			 = 1;
		IF @ReviewUsrPayRowList IS NOT NULL SET @ReviewUsrPayRowList_ALL = 1;
		IF @CurrencyIDList      IS NOT NULL SET @CurrencyIDList_ALL      = 1;
		IF @DebitAmountFrom     IS NOT NULL SET @DebitAmountFrom_ALL     = 1;
		IF @DebitAmountTo       IS NOT NULL SET @DebitAmountTo_ALL       = 1;
		IF @CreditAmountFrom    IS NOT NULL SET @CreditAmountFrom_ALL    = 1;
		IF @CreditAmountTo      IS NOT NULL SET @CreditAmountTo_ALL      = 1;
		IF @AccDocDesc          IS NOT NULL SET @AccDocDesc_ALL          = 1;
		IF @TrackingNumber      IS NOT NULL SET @TrackingNumber          = 1;
		IF ISNULL(@BranchCodeList,'')      <>'' SET @BranchCodeList_All      = 1;
		-------------------------------------------------------------------------
		DECLARE @TotStartDate         DATE         , @TotEndDate         DATE ,
		        @StartFinanAllocate   SMALLINT     , @EndFinanAllocate   SMALLINT 
		----------------------------------------------------
	  DECLARE @AccDockind     TABLE (AccdocKindCode    INT )
		-----------------------------------------------------
		DECLARE @AccDocState    TABLE (DocStateID        INT ) 
		-----------------------------------------------------
		DECLARE @UsrList        TABLE (UsrPayRow         INT )
		-----------------------------------------------------
		DECLARE @ReviewUsrList  TABLE (ReviewUsrPayRow   INT )
		------------------------------------------------------
		DECLARE @CurrencyList   TABLE (CurrencyID        INT )
		-----------------------------------------------------
		DECLARE @AccPriority    TABLE (RowNo   TINYINT,AccKind   TINYINT,AccKindCodeName   NVARCHAR(50),AccKindName   NVARCHAR(50))
		------------------------------------------------------
		DECLARE @BranchList     TABLE (BrchCode          INT )
		-----------------------------------------------------

		DECLARE @CodingList     TABLE 
		                           (RowNo																					INT								,
                               -- AccDocState                                   TINYINT           ,
																--BranchCode                                    INT               ,
																AccMTMapID																		BIGINT						,
																GroupCode																			BIGINT						,
																KolCode																				BIGINT						,
																MoeenCode																			BIGINT						,
																GroupName																			NVARCHAR(500)			,
																KolName																				NVARCHAR(500)			,
																MoeenName																			NVARCHAR(500)			,
																AccTafID4																			BIGINT						,
																AccTafID5																			BIGINT						,
																AccTafID6																			BIGINT						,
																AccTafsilName4																NVARCHAR(500)			,
																AccTafsilName5																NVARCHAR(500)			,
																AccTafsilName6																NVARCHAR(500)			,
																CurrencyID                                    SMALLINT          ,
																BaseCurrencyID																SMALLINT          ,
																CurrencyRate                                  DECIMAL(25,6)     ,
																AmountCurrency                                DECIMAL(25,6)     ,
																CurrencyChangeRate                            DECIMAL(25,6)     ,
																DebitCreditFlag                               BIT               ,
																DebitCirculationBeforePeriod									DECIMAL(22,6)DEFAULT 0      ,
																CreditCirculationBeforePeriod                 DECIMAL(22,6)DEFAULT 0      ,
																DebitCirculationDuringPeriod									DECIMAL(22,6)DEFAULT 0      ,
																CreditCirculationDuringPeriod                 DECIMAL(22,6)DEFAULT 0      ,
																DebitCirculationSoFarPeriod									  DECIMAL(22,6)DEFAULT 0      ,--گردش بدههکار تا کنون 
																CreditCirculationSoFarPeriod                  DECIMAL(22,6)DEFAULT 0      ,-- گردش بستانکار تا کنون 
																DebitRemainDuringPeriod									      DECIMAL(22,6)DEFAULT 0      ,
																CreditRemainDuringPeriod                      DECIMAL(22,6)DEFAULT 0      
															 ) 
		------------------------------------------------------
		DECLARE @Taraz          TABLE 
		                           (RowNo																					INT								,
                             		GroupCode																			BIGINT						,
																KolCode																				BIGINT						,
																MoeenCode																			BIGINT						,
																GroupName																			NVARCHAR(500)			,
																KolName																				NVARCHAR(500)			,
																MoeenName																			NVARCHAR(500)			,
																AccTafID4																			BIGINT						,
																AccTafID5																			BIGINT						,
																AccTafID6																			BIGINT						,
																AccTafsilName4																NVARCHAR(500)			,
																AccTafsilName5																NVARCHAR(500)			,
																AccTafsilName6																NVARCHAR(500)			,
																CurrencyID                                    SMALLINT          ,
																BaseCurrencyID																SMALLINT          ,
																CurrencyRate                                  DECIMAL(25,6)     ,
																AmountCurrency                                DECIMAL(25,6)     ,
																CurrencyChangeRate                            DECIMAL(25,6)     ,
																DebitCreditFlag                               BIT               ,
																DebitCirculationBeforePeriod									DECIMAL(22,6)DEFAULT 0      ,
																CreditCirculationBeforePeriod                 DECIMAL(22,6)DEFAULT 0      ,
																DebitCirculationDuringPeriod									DECIMAL(22,6)DEFAULT 0      ,
																CreditCirculationDuringPeriod                 DECIMAL(22,6)DEFAULT 0      ,
																DebitCirculationSoFarPeriod									  DECIMAL(22,6)DEFAULT 0      ,--گردش بدههکار تا کنون 
																CreditCirculationSoFarPeriod                  DECIMAL(22,6)DEFAULT 0      ,-- گردش بستانکار تا کنون 
																DebitRemainDuringPeriod									      DECIMAL(22,6)DEFAULT 0      ,
																CreditRemainDuringPeriod                      DECIMAL(22,6)DEFAULT 0      
															 ) 
		------------------------------------------------------
		DECLARE @AccKindList    TABLE   ( AccKind   TINYINT , AccKindCodeName   NVARCHAR(50),AccKindName   NVARCHAR(50)) 
		------------------------------------------------------
		SET @TotStartDate       = (SELECT  CAST(FinancialAllocateStartDate AS DATE ) FROM dbo.FinancialAllocate  WHERE FinancialPeriodID = @FinancialPeriodIDFrom )													  
		SET @TotEndDate         = (SELECT  CAST(FinancialAllocateEndDate   AS DATE ) FROM dbo.FinancialAllocate  WHERE FinancialPeriodID = @FinancialPeriodIDTo   )	
		SET @StartFinanAllocate = (SELECT  FinancialAllocateID                       FROM dbo.FinancialAllocate  WHERE KolNotBookID      = 1 AND FinancialPeriodID = @FinancialPeriodIDFrom   )												  
		SET @EndFinanAllocate   = (SELECT  FinancialAllocateID                       FROM dbo.FinancialAllocate  WHERE KolNotBookID      = 1 AND FinancialPeriodID = @FinancialPeriodIDTo     )												  
		-------------------------------------------------------------
		 IF @FinancialPeriodIDFrom NOT IN ( SELECT FinancialPeriodID FROM  dbo.FinancialPeriod)
		    OR 
				@FinancialPeriodIDTo   NOT IN ( SELECT FinancialPeriodID FROM  dbo.FinancialPeriod)
		 BEGIN 
		     RAISERROR (' شناسه ((دوره مالی  )) نامعتبر است  ',18,1)
		 END 
	  -----------------------------------------------------------------
			IF @StartDate < @TotStartDate 
			BEGIN 
					RAISERROR ( ' تاریخ شروع در محدوده دوره مالی ((از )) نیست  ',18,1)
			END 
			IF @EndDate  > @TotEndDate
			BEGIN 
					RAISERROR (' تاریخ پایان در محدوده دور مالی ((تا))نیست  ',18,1)
			END  
		-------------------------------------------------------------
		INSERT INTO @AccKindList( AccKind, AccKindCodeName,AccKindName)
		VALUES
		       ( 1,'GroupCode' ,'GroupName'     ),
					 ( 2,'KolCode'   ,'KolName'       ),
					 ( 3,'MoeenCode' ,'MoeenName'     ),
					 ( 4,'AccTafID4' ,'AccTafsilName4'),
					 ( 5,'AccTafID5' ,'AccTafsilName5'),
					 ( 6,'AccTafID6' ,'AccTafsilName6')
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
		---------------------------------------------------------------------------------------------------------
		IF @UsrPayRowList IS NOT NULL 
    BEGIN 
	 	 		INSERT INTO @UsrList	(UsrPayRow)
	 	 	  SELECT * FROM Split   (@UsrPayRowList,',')
    END
		---------------------------------------------------------------------------------------------------------
		IF @ReviewUsrPayRowList IS NOT NULL 
    BEGIN 
	 	 		INSERT INTO @ReviewUsrList	( ReviewUsrPayRow)
	 	 	  SELECT * FROM Split         (@ReviewUsrPayRowList,',')
    END
	 ---------------------------------------------------------------------------------------------------------
		IF @CurrencyIDList IS NOT NULL 
    BEGIN 
	 	 		INSERT INTO @CurrencyList (CurrencyID)
	 	 		SELECT * FROM Split       (@CurrencyIDList,',')
    END
		---------------------------------------------------------------------------------------------------------
		IF ISNULL(@BranchCodeList,'') <>''
		BEGIN 
		    INSERT INTO @BranchList  (BrchCode)
		    SELECT * FROM dbo.Split(@BranchCodeList ,',')
		END 
		---------------------------------------------------------------------------------------------------------
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
				  SET @MaxRow           =  (SELECT MAX(RowNo)       FROM @AccPriority )
					SET @DelRow           =  (SELECT AccKind          FROM @AccPriority  WHERE RowNo = @MaxRow AND RowNo > 1 )
					SET @DelRowName       =  (SELECT AccKindName      FROM @AccPriority  WHERE RowNo = @MaxRow AND RowNo > 1 )
					SET @DelRowKindName   =  (SELECT AccKindCodeName  FROM @AccPriority  WHERE RowNo = @MaxRow AND RowNo > 1 ) 
					
					DELETE FROM @AccPriority WHERE RowNo = @MaxRow AND RowNo > 1 -- حذف اخرین سطح
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
				INSERT INTO @CodingList
									 (RowNo     ,AccMTMapID ,GroupCode ,KolCode  ,MoeenCode     ,GroupName     ,KolName,
										MoeenName ,AccTafID4  ,AccTafID5 ,AccTafID6,AccTafsilName4,AccTafsilName5,AccTafsilName6
									 )
				SELECT  ROW_NUMBER() OVER (ORDER BY dbo.VWAccMTList.AccMTMapID  ) RowNo ,
 								AccMTMapID ,GroupCode ,KolCode  ,MoeenCode,GroupName     ,KolName,
								MoeenName  ,AccTafID4 ,AccTafID5,AccTafID6,AccTafsilName4,AccTafsilName5,AccTafsilName6
				FROM dbo.VWAccMTList
							INNER  JOIN dbo.AccCoding ON dbo.AccCoding.AccCode = dbo.VWAccMTList.MoeenCode
				WHERE (CurrencyProperty = @CurrencyProperty OR @CurrencyProperty  IS NULL )
							 AND 
							 (AccActive        = 1                OR AccActive =  @AccActive     )
							 AND 
							 (FollowupProperty = @FollowupProperty  OR @FollowupProperty IS NULL  )
							 AND 
							 (CountProperty    = @CountProperty     OR @CountProperty    IS NULL )
		 -----------------------------------------------------------------------------------
		-- SELECT * FROM @CodingList --**==
		 -------------------------------------------------------------------------------------
				  UPDATE @CodingList  SET DebitCirculationDuringPeriod   = T10.DebitAmount      ,
					                        CreditCirculationDuringPeriod  = T10.CreditAmount   ,
																	DebitRemainDuringPeriod        = CASE WHEN T10.DebitAmount  - T10.CreditAmount  > 0 THEN T10.DebitAmount  - T10.CreditAmount ELSE 0 END ,
																	CreditRemainDuringPeriod       = CASE WHEN T10.CreditAmount - T10.DebitAmount   > 0 THEN T10.CreditAmount - T10.DebitAmount  ELSE 0 END  
					
					FROM (                        
								SELECT  T11.AccMTMapID , SUM(T11.DebitAmount) DebitAmount , SUM(T11.CreditAmount) CreditAmount 
								FROM (
														 SELECT T12.AccMTMapID , CASE WHEN T12.DebitCreditFlag = 1 THEN AccDocDtlAmount ELSE 0  END  DebitAmount 
																									 , CASE WHEN T12.DebitCreditFlag = 0 THEN AccDocDtlAmount ELSE 0  END  CreditAmount 
														 FROM (
																	 SELECT AccDocDetail.AccMTMapID , ISNULL(SUM(AccDocDetail.AccDocDtlAmount),0)  AccDocDtlAmount , AccDocDetail.DebitCreditFlag
																	 FROM   dbo.AccDoc
																					INNER JOIN  dbo.AccDocDetail ON AccDocDetail.AccDocID = AccDoc.AccDocId
																					INNER JOIN  @CodingList      ON [@CodingList].AccMTMapID = AccDocDetail.AccMTMapID

																	 WHERE  AccDocDate  BETWEEN  @TotStartDate  AND @TotEndDate
																					AND 
																					AccDocDate  BETWEEN  @StartDate     AND @EndDate
																					AND 
																					(@BranchCodeList_All      = 0   OR (dbo.AccDoc.BranchCode       IN (SELECT BranchCode     FROM @BranchList  )))
																					AND 
																					(@AccDocNoFrom_ALL        = 0    				  OR (AccDocNo 		             >= @AccDocNoFrom))
																					AND
																					(@AccDocNoTo_ALL          = 0    				  OR (AccDocNo 		              <= @AccDocNoTo  ))
																					AND  
																					(@AccDocKindList_ALL      = 0             OR (AccDocKindCode            IN (SELECT AccdocKindCode FROM @AccDockind)))
																					AND 
																					(@AccReferNoFrom_ALL      = 0    				  OR (AccDocReferNo 		         >= @AccReferNoFrom))
																					AND 
																					(@AccReferNoTo_ALL        = 0    				  OR (AccDocReferNo 		         <= @AccReferNoTo))
																					AND
																					(@AccDocStateList_ALL     = 0             OR (AccDoc.AccDocState		      IN (SELECT DocStateID FROM @AccDocState)))
																					AND  
																					(@UsrPayRowList_ALL       = 0             OR (AccDoc.UsrPayrow			      IN (SELECT UsrPayRow FROM @UsrList )))
																					AND 
																					(@CurrencyIDList_ALL      = 0             OR (AccDocDetail.CurrencyID     IN (SELECT CurrencyID  FROM @CurrencyList)))
																					AND
																					(@DebitAmountFrom_ALL     = 0             OR (AccDocDetail.DebitCreditFlag = 1 AND AccDocDetail.AccDocDtlAmount >= @DebitAmountFrom))
																					AND 
																					(@DebitAmountTo_ALL       = 0             OR (AccDocDetail.DebitCreditFlag = 1 AND AccDocDetail.AccDocDtlAmount <= @DebitAmountTo))
																					AND 
																					(@CreditAmountFrom_ALL    = 0             OR (AccDocDetail.DebitCreditFlag = 0 AND AccDocDetail.AccDocDtlAmount >= @CreditAmountFrom))
																					AND 
																					(@CreditAmountTo_ALL      = 0             OR (AccDocDetail.DebitCreditFlag = 0 AND AccDocDetail.AccDocDtlAmount <= @CreditAmountTo))
																					AND 
																					(@AccDocDesc_ALL          = 0             OR (AccDocDesc LIKE '%'+@AccDocDesc+'%'))
																					AND 
																					(@TrackingNumber_ALL      = 0             OR (TrackingNumber = @TrackingNumber))
																					AND 
																					(@ReviewUsrPayRowList_ALL = 0             OR (AccDoc.AccDocId IN (SELECT dbo.AccDocStatus.AccDocId FROM dbo.AccDocStatus 
																																																						WHERE AccDocState = 2  AND UsrPayrow IN (SELECT ReviewUsrPayRow FROM @ReviewUsrList))))
																					
																		GROUP BY CASE WHEN ISNULL(@CurrencyProperty,0) = 1  AND @CurrencyBase = 1 THEN dbo.AccDocDetail.BaseCurrencyID
																		              WHEN ISNULL(@CurrencyProperty,0) = 1  AND @CurrencyBase = 2 THEN dbo.AccDocDetail.CurrencyID
																						 END ,
																		 AccDocDetail.AccMTMapID,AccDocDetail.DebitCreditFlag
														 )T12
											)T11
											GROUP BY T11.AccMTMapID
							 )T10 
						WHERE T10.AccMTMapID = [@CodingList].AccMTMapID
				--		SELECT * FROM @CodingList --**==
		------------------------------------------------------------------------------------------------------------------------------
		 IF EXISTS (SELECT  * FROM @AccountList )
		 BEGIN 
				 IF EXISTS (SELECT * FROM @AccountList  WHERE AccKind = 1)
				 BEGIN 
						DELETE FROM @CodingList 
						WHERE GroupCode NOT IN (SELECT AccCode FROM @AccCodeList WHERE AccKind = 1 )
				 END 
				 ----------------------------------------------------------------------
				 IF EXISTS (SELECT * FROM @AccountList  WHERE AccKind = 2)
				 BEGIN 
						DELETE FROM @CodingList 
						WHERE KolCode NOT IN (SELECT AccCode FROM @AccCodeList WHERE AccKind = 2 )
				 END      
				 ------------------------------------------------------------------------
				 IF EXISTS (SELECT * FROM @AccountList  WHERE AccKind = 3)
				 BEGIN 
						DELETE FROM @CodingList 
						WHERE MoeenCode NOT IN (SELECT AccCode FROM @AccCodeList WHERE AccKind = 3 )
				 END 
				 -------------------------------------------------------------------------------
				 IF EXISTS (SELECT * FROM @AccountList  WHERE AccKind = 4)
				 BEGIN 
						DELETE FROM @CodingList 
						WHERE  AccTafID4 NOT IN (SELECT AccCode FROM @AccCodeList WHERE AccKind = 4 )
				 END 
				 --------------------------------------------------------------------------------
				 IF EXISTS (SELECT * FROM @AccountList  WHERE AccKind = 5)
				 BEGIN 
						DELETE FROM @CodingList 
						WHERE AccTafID5 NOT IN (SELECT AccCode FROM @AccCodeList WHERE AccKind = 5 )
				 END 
				 -------------------------------------------------------------------------------
				 IF EXISTS (SELECT * FROM @AccountList  WHERE AccKind = 6)
				 BEGIN 
						DELETE FROM @CodingList 
						WHERE AccTafID6 NOT IN (SELECT AccCode FROM @AccCodeList WHERE AccKind = 6 )
				 END 
			 -------------------------------------------------------------------------------
		 END 
	
	-- SELECT * FROM @CodingList --**==
		--------------------------------------================== ColumnKid Section ====================-----------------------------
		IF @ReportColumnKind  IN ( 6 , 8)
		BEGIN
		    UPDATE @CodingList  SET   DebitCirculationBeforePeriod   = T20.DebitAmount     ,
					                        CreditCirculationBeforePeriod  = T20.CreditAmount   

				 FROM (  
								SELECT  T21.AccMTMapID , SUM(T21.DebitAmount) DebitAmount , SUM(T21.CreditAmount) CreditAmount 
								FROM (
														 SELECT T22.AccMTMapID , CASE WHEN T22.DebitCreditFlag = 1 THEN AccDocDtlAmount ELSE 0  END  DebitAmount 
																									 , CASE WHEN T22.DebitCreditFlag = 0 THEN AccDocDtlAmount ELSE 0  END  CreditAmount 
														 FROM (
																	 SELECT AccDocDetail.AccMTMapID , SUM(AccDocDetail.AccDocDtlAmount)  AccDocDtlAmount , AccDocDetail.DebitCreditFlag
																	 FROM   dbo.AccDoc
																					INNER JOIN  dbo.AccDocDetail ON AccDocDetail.AccDocID = AccDoc.AccDocId
																					INNER JOIN  @CodingList      ON [@CodingList].AccMTMapID = AccDocDetail.AccMTMapID

																	 WHERE 	AccDocDate  <  @StartDate     
																				
																		GROUP BY AccDocDetail.AccMTMapID,AccDocDetail.DebitCreditFlag
														    )T22
											)T21
											GROUP BY T21.AccMTMapID
							)T20 
						  WHERE T20.AccMTMapID = [@CodingList].AccMTMapID
		END 
		------------------------------------------------------------------------------------------
		IF @ReportColumnKind = 8
		BEGIN
		     UPDATE @CodingList  SET  DebitCirculationSoFarPeriod   = T20.DebitAmount     ,
					                        CreditCirculationSoFarPeriod  = T20.CreditAmount   

				 FROM (  
								SELECT  T21.AccMTMapID , SUM(T21.DebitAmount) DebitAmount , SUM(T21.CreditAmount) CreditAmount 
								FROM (
														 SELECT T22.AccMTMapID , CASE WHEN T22.DebitCreditFlag = 1 THEN AccDocDtlAmount ELSE 0  END  DebitAmount 
																									 , CASE WHEN T22.DebitCreditFlag = 0 THEN AccDocDtlAmount ELSE 0  END  CreditAmount 
														 FROM (
																	 SELECT AccDocDetail.AccMTMapID , SUM(AccDocDetail.AccDocDtlAmount)  AccDocDtlAmount , AccDocDetail.DebitCreditFlag
																	 FROM   dbo.AccDoc
																					INNER JOIN  dbo.AccDocDetail ON AccDocDetail.AccDocID = AccDoc.AccDocId
																					INNER JOIN  @CodingList      ON [@CodingList].AccMTMapID = AccDocDetail.AccMTMapID

																	 WHERE 	AccDocDate  <  @EndDate     
																				
																		GROUP BY AccDocDetail.AccMTMapID,AccDocDetail.DebitCreditFlag
														    )T22
											)T21
											GROUP BY T21.AccMTMapID
							)T20 
						  WHERE T20.AccMTMapID = [@CodingList].AccMTMapID
		END 
		-----------------------------------------------------------------------------------------
		  --SELECT * FROM @CodingList  ORDER BY GroupName 
		--SELECT * FROM @AccPriority --**==
		--SELECT @P1,@P2,@P3,@P4,@P5,@P6 
		--SELECT @DelRow delroe , @MaxRow maxrow , @DelRowName delrowname 
		IF (SELECT COUNT(*) FROM @AccPriority) > 0 
		BEGIN 
		    INSERT INTO @Taraz
		          (  RowNo          , GroupCode   ,  KolCode       , MoeenCode          ,-- GroupName      , KolName        , MoeenName,
		             AccTafID4      , AccTafID5   ,  AccTafID6     , /*AccTafsilName4     , AccTafsilName5 , AccTafsilName6 , CurrencyID,
		             BaseCurrencyID , CurrencyRate, AmountCurrency , CurrencyChangeRate , DebitCreditFlag,*/
		             DebitCirculationBeforePeriod , CreditCirculationBeforePeriod,
		             DebitCirculationDuringPeriod , CreditCirculationDuringPeriod,
		             DebitCirculationSoFarPeriod  , CreditCirculationSoFarPeriod,
		             DebitRemainDuringPeriod      , CreditRemainDuringPeriod
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
																								END ASC 
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
					       DebitCirculationBeforePeriod , CreditCirculationBeforePeriod,
		             DebitCirculationDuringPeriod , CreditCirculationDuringPeriod,
		             DebitCirculationSoFarPeriod  , CreditCirculationSoFarPeriod,
		             DebitRemainDuringPeriod      , CreditRemainDuringPeriod
	      FROM (		
			        SELECT  
									             CASE   WHEN @P1     = 1 THEN GroupCode WHEN @P1     = 2 THEN KolCode   
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
																,CASE WHEN @P4 = 1     THEN GroupCode WHEN @P4 = 2     THEN KolCode 
																			WHEN @P4 = 3     THEN MoeenCode WHEN @P4 = 4     THEN AccTafID4
									 										WHEN @P4 = 5     THEN AccTafID5 WHEN @P4 = 6     THEN AccTafID6
																			WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
																			WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 										WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
																END C4
																--------------------------------------------------------
																,CASE WHEN @P5 = 1 THEN GroupCode WHEN @P5 = 2 THEN KolCode
																			WHEN @P5 = 3 THEN MoeenCode WHEN @P5 = 4 THEN AccTafID4
									 										WHEN @P5 = 5 THEN AccTafID5 WHEN @P5 = 6 THEN AccTafID6
																			WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
																			WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 										WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
																END  C5
																--------------------------------------------------------
																,CASE WHEN @P6 = 1 THEN GroupCode WHEN @P6 = 2 THEN KolCode 
																			WHEN @P6 = 3 THEN MoeenCode WHEN @P6 = 4 THEN AccTafID4
									 										WHEN @P6 = 5 THEN AccTafID5 WHEN @P6 = 6 THEN AccTafID6
																			WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
																			WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 										WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
																END   C6  ,
									SUM(DebitCirculationBeforePeriod) DebitCirculationBeforePeriod  , SUM(CreditCirculationBeforePeriod) CreditCirculationBeforePeriod,
									SUM(DebitCirculationDuringPeriod) DebitCirculationDuringPeriod  , SUM(CreditCirculationDuringPeriod) CreditCirculationDuringPeriod,
									SUM(DebitCirculationSoFarPeriod ) DebitCirculationSoFarPeriod   , SUM(CreditCirculationSoFarPeriod ) CreditCirculationSoFarPeriod  ,
									CASE WHEN SUM(DebitCirculationDuringPeriod)   - SUM(CreditCirculationDuringPeriod) > 0 THEN SUM(DebitCirculationDuringPeriod) - SUM(CreditCirculationDuringPeriod) ELSE 0 END   DebitRemainDuringPeriod ,
									CASE WHEN SUM(CreditCirculationDuringPeriod)  - SUM(DebitCirculationDuringPeriod)  > 0 THEN SUM(CreditCirculationDuringPeriod)- SUM(DebitCirculationDuringPeriod)  ELSE 0 END   CreditRemainDuringPeriod
				  FROM @CodingList
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
																,CASE WHEN @P5 = 1 THEN GroupCode WHEN @P5 = 2 THEN KolCode
																			WHEN @P5 = 3 THEN MoeenCode WHEN @P5 = 4 THEN AccTafID4
									 										WHEN @P5 = 5 THEN AccTafID5 WHEN @P5 = 6 THEN AccTafID6
																			WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
																			WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 										WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
																END 
																--------------------------------------------------------
																,CASE WHEN @P6 = 1 THEN GroupCode WHEN @P6 = 2 THEN KolCode 
																			WHEN @P6 = 3 THEN MoeenCode WHEN @P6 = 4 THEN AccTafID4
									 										WHEN @P6 = 5 THEN AccTafID5 WHEN @P6 = 6 THEN AccTafID6
																			WHEN @DelRow = 1 THEN GroupCode WHEN @DelRow = 2 THEN KolCode
																			WHEN @DelRow = 3 THEN MoeenCode WHEN @DelRow = 4 THEN AccTafID4
									 										WHEN @DelRow = 5 THEN AccTafID5 WHEN @DelRow = 6 THEN AccTafID6
																END
				) T
		---------------------------------------------------------------------------------------------------------------------
		  ------------------------------------------======= Remain Kind Section ==============------------------------------------------
		--SELECT * FROM @Taraz --**==
		
		-- DELETE FROM /*@CodingList*/@Taraz WHERE ISNULL(DebitCirculationDuringPeriod,0) = 0 AND ISNULL(CreditCirculationDuringPeriod,0) = 0 
		 --SELECT * FROM @Taraz --**==
		 IF @RemainKind = 4 
		 BEGIN 
		      DELETE FROM  /*@CodingList*/@Taraz WHERE CreditRemainDuringPeriod > 0 
		 END 
		        -----------------------------------------------------
		 IF @RemainKind = 5
		 BEGIN 
		      DELETE FROM  /*@CodingList*/@Taraz WHERE DebitRemainDuringPeriod > 0 
		 END 
		    -----------------------------------------------------
		 IF @RemainKind = 6
		 BEGIN 
		      DELETE FROM  /*@CodingList*/@Taraz WHERE ISNULL(DebitRemainDuringPeriod,0) = 0  AND  ISNULL(CreditRemainDuringPeriod,0) = 0
		 END 
		 -----------------------------------------------------
		 IF @RemainKind = 7
		 BEGIN 
		      DELETE FROM  /*@CodingList*/@Taraz WHERE ISNULL(DebitRemainDuringPeriod,0) > 0 OR   ISNULL(CreditRemainDuringPeriod,0) > 0
		 END 		     
		
		---------------------------------------------------------------------------------------------------------------------
							 SELECT RowNo          , GroupCode   ,  KolCode       , MoeenCode          ,A_1.AccName  GroupName      , A_2.AccName  KolName        ,A_3.AccName MoeenName,
		                  AccTafID4      , AccTafID5   ,  AccTafID6     , T_4.AccTafsilName  AccTafsilName4     , T_5.AccTafsilName AccTafsilName5 , T_6.AccTafsilName AccTafsilName6 , CurrencyID,
											BaseCurrencyID , CurrencyRate, AmountCurrency , CurrencyChangeRate , DebitCreditFlag,
											DebitCirculationBeforePeriod , CreditCirculationBeforePeriod,
											DebitCirculationDuringPeriod , CreditCirculationDuringPeriod,
											DebitCirculationSoFarPeriod  , CreditCirculationSoFarPeriod,
											DebitRemainDuringPeriod      , CreditRemainDuringPeriod 
							 FROM @Taraz 
							      LEFT JOIN dbo.AccCoding   A_1  ON [@Taraz].GroupCode  = A_1.AccCode
										LEFT JOIN dbo.AccCoding   A_2  ON [@Taraz].KolCode    = A_2.AccCode
										LEFT JOIN dbo.AccCoding   A_3  ON [@Taraz].MoeenCode  = A_3.AccCode
										LEFT JOIN dbo.AccTafsil   T_4  ON [@Taraz].AccTafID4  = T_4.AccTafID
										LEFT JOIN dbo.AccTafsil   T_5  ON [@Taraz].AccTafID5  = T_5.AccTafID
										LEFT JOIN dbo.AccTafsil   T_6  ON [@Taraz].AccTafID6  = T_6.AccTafID
    ----------------------------------------------------------------------------------------
		 --SELECT * FROM @Taraz --**==
		END -- IF (SELECT COUNT(*) FROM @AccPriority) > 0 
		/*ELSE 
		BEGIN 
       SELECT   ROW_NUMBER()  OVER 
				       (PARTITION BY  CASE  WHEN @P1 = 1 THEN GroupCode WHEN @P1 = 2 THEN KolCode
																		WHEN @P1 = 3 THEN MoeenCode WHEN @P1 = 4 THEN AccTafID4
																		WHEN @P1 = 5 THEN AccTafID5 WHEN @P1 = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
															 	,CASE WHEN @P2 = 1 THEN GroupCode WHEN @P2 = 2 THEN KolCode
																			WHEN @P2 = 3 THEN MoeenCode WHEN @P2 = 4 THEN AccTafID4
									 										WHEN @P2 = 5 THEN AccTafID5 WHEN @P2 = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
																,CASE WHEN @P3 = 1 THEN GroupCode WHEN @P3 = 2 THEN KolCode
																			WHEN @P3 = 3 THEN MoeenCode WHEN @P3 = 4 THEN AccTafID4
									 										WHEN @P3 = 5 THEN AccTafID5 WHEN @P3 = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
																,CASE WHEN @P4 = 1 THEN GroupCode WHEN @P4 = 2 THEN KolCode 
																			WHEN @P4 = 3 THEN MoeenCode WHEN @P4 = 4 THEN AccTafID4
									 										WHEN @P4 = 5 THEN AccTafID5 WHEN @P4 = 6 THEN AccTafID6
																END 
																--------------------------------------------------------
																,CASE WHEN @P5 = 1 THEN GroupCode WHEN @P5 = 2 THEN KolCode
																			WHEN @P5 = 3 THEN MoeenCode WHEN @P5 = 4 THEN AccTafID4
									 										WHEN @P5 = 5 THEN AccTafID5 WHEN @P5 = 6 THEN AccTafID6
																END 
																--------------------------------------------------------
																,CASE WHEN @P6 = 1 THEN GroupCode WHEN @P6 = 2 THEN KolCode 
																			WHEN @P6 = 3 THEN MoeenCode WHEN @P6 = 4 THEN AccTafID4
									 										WHEN @P6 = 5 THEN AccTafID5 WHEN @P6 = 6 THEN AccTafID6
																END
									ORDER BY    CASE  WHEN @P1 = 1 THEN GroupCode WHEN @P1 = 2 THEN KolCode
																		WHEN @P1 = 3 THEN MoeenCode WHEN @P1 = 4 THEN AccTafID4
																		WHEN @P1 = 5 THEN AccTafID5 WHEN @P1 = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
															 	,CASE WHEN @P2 = 1 THEN GroupCode WHEN @P2 = 2 THEN KolCode
																			WHEN @P2 = 3 THEN MoeenCode WHEN @P2 = 4 THEN AccTafID4
									 										WHEN @P2 = 5 THEN AccTafID5 WHEN @P2 = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
																,CASE WHEN @P3 = 1 THEN GroupCode WHEN @P3 = 2 THEN KolCode
																			WHEN @P3 = 3 THEN MoeenCode WHEN @P3 = 4 THEN AccTafID4
									 										WHEN @P3 = 5 THEN AccTafID5 WHEN @P3 = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
																,CASE WHEN @P4 = 1 THEN GroupCode WHEN @P4 = 2 THEN KolCode 
																			WHEN @P4 = 3 THEN MoeenCode WHEN @P4 = 4 THEN AccTafID4
									 										WHEN @P4 = 5 THEN AccTafID5 WHEN @P4 = 6 THEN AccTafID6
																END 
																--------------------------------------------------------
																,CASE WHEN @P5 = 1 THEN GroupCode WHEN @P5 = 2 THEN KolCode
																			WHEN @P5 = 3 THEN MoeenCode WHEN @P5 = 4 THEN AccTafID4
									 										WHEN @P5 = 5 THEN AccTafID5 WHEN @P5 = 6 THEN AccTafID6
																END 
																--------------------------------------------------------
																,CASE WHEN @P6 = 1 THEN GroupCode WHEN @P6 = 2 THEN KolCode 
																			WHEN @P6 = 3 THEN MoeenCode WHEN @P6 = 4 THEN AccTafID4
									 										WHEN @P6 = 5 THEN AccTafID5 WHEN @P6 = 6 THEN AccTafID6
																END
										ASC 
                 ) RowNo,      
			              /*AccMTMapID ,GroupCode ,KolCode  ,MoeenCode     ,GroupName     ,KolName,
										MoeenName ,AccTafID4  ,AccTafID5 ,AccTafID6,AccTafsilName4,AccTafsilName5,AccTafsilName6,*/
										 CASE  WHEN @P1 = 1 THEN GroupCode WHEN @P1 = 2 THEN KolCode
																		WHEN @P1 = 3 THEN MoeenCode WHEN @P1 = 4 THEN AccTafID4
																		WHEN @P1 = 5 THEN AccTafID5 WHEN @P1 = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
															 	,CASE WHEN @P2 = 1 THEN GroupCode WHEN @P2 = 2 THEN KolCode
																			WHEN @P2 = 3 THEN MoeenCode WHEN @P2 = 4 THEN AccTafID4
									 										WHEN @P2 = 5 THEN AccTafID5 WHEN @P2 = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
																,CASE WHEN @P3 = 1 THEN GroupCode WHEN @P3 = 2 THEN KolCode
																			WHEN @P3 = 3 THEN MoeenCode WHEN @P3 = 4 THEN AccTafID4
									 										WHEN @P3 = 5 THEN AccTafID5 WHEN @P3 = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
																,CASE WHEN @P4 = 1 THEN GroupCode WHEN @P4 = 2 THEN KolCode 
																			WHEN @P4 = 3 THEN MoeenCode WHEN @P4 = 4 THEN AccTafID4
									 										WHEN @P4 = 5 THEN AccTafID5 WHEN @P4 = 6 THEN AccTafID6
																END 
																--------------------------------------------------------
																,CASE WHEN @P5 = 1 THEN GroupCode WHEN @P5 = 2 THEN KolCode
																			WHEN @P5 = 3 THEN MoeenCode WHEN @P5 = 4 THEN AccTafID4
									 										WHEN @P5 = 5 THEN AccTafID5 WHEN @P5 = 6 THEN AccTafID6
																END 
																--------------------------------------------------------
																,CASE WHEN @P6 = 1 THEN GroupCode WHEN @P6 = 2 THEN KolCode 
																			WHEN @P6 = 3 THEN MoeenCode WHEN @P6 = 4 THEN AccTafID4
									 										WHEN @P6 = 5 THEN AccTafID5 WHEN @P6 = 6 THEN AccTafID6
																END,
									SUM(DebitCirculationBeforePeriod) DebitCirculationBeforePeriod  , SUM(CreditCirculationBeforePeriod) CreditCirculationBeforePeriod,
									SUM(DebitCirculationDuringPeriod) DebitCirculationDuringPeriod  , SUM(CreditCirculationDuringPeriod) CreditCirculationDuringPeriod,
									SUM(DebitCirculationSoFarPeriod ) DebitCirculationSoFarPeriod   , SUM(CreditCirculationSoFarPeriod ) CreditCirculationSoFarPeriod  ,
									SUM(DebitRemainDuringPeriod     ) DebitRemainDuringPeriod       , SUM(CreditRemainDuringPeriod     ) CreditRemainDuringPeriod

			 FROM @CodingList 
		   GROUP BY  CASE  WHEN @P1 = 1 THEN GroupCode WHEN @P1 = 2 THEN KolCode
																		WHEN @P1 = 3 THEN MoeenCode WHEN @P1 = 4 THEN AccTafID4
																		WHEN @P1 = 5 THEN AccTafID5 WHEN @P1 = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
															 	,CASE WHEN @P2 = 1 THEN GroupCode WHEN @P2 = 2 THEN KolCode
																			WHEN @P2 = 3 THEN MoeenCode WHEN @P2 = 4 THEN AccTafID4
									 										WHEN @P2 = 5 THEN AccTafID5 WHEN @P2 = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
																,CASE WHEN @P3 = 1 THEN GroupCode WHEN @P3 = 2 THEN KolCode
																			WHEN @P3 = 3 THEN MoeenCode WHEN @P3 = 4 THEN AccTafID4
									 										WHEN @P3 = 5 THEN AccTafID5 WHEN @P3 = 6 THEN AccTafID6
																END 
																		--------------------------------------------------------
																,CASE WHEN @P4 = 1 THEN GroupCode WHEN @P4 = 2 THEN KolCode 
																			WHEN @P4 = 3 THEN MoeenCode WHEN @P4 = 4 THEN AccTafID4
									 										WHEN @P4 = 5 THEN AccTafID5 WHEN @P4 = 6 THEN AccTafID6
																END 
																--------------------------------------------------------
																,CASE WHEN @P5 = 1 THEN GroupCode WHEN @P5 = 2 THEN KolCode
																			WHEN @P5 = 3 THEN MoeenCode WHEN @P5 = 4 THEN AccTafID4
									 										WHEN @P5 = 5 THEN AccTafID5 WHEN @P5 = 6 THEN AccTafID6
																END 
																--------------------------------------------------------
																,CASE WHEN @P6 = 1 THEN GroupCode WHEN @P6 = 2 THEN KolCode 
																			WHEN @P6 = 3 THEN MoeenCode WHEN @P6 = 4 THEN AccTafID4
									 										WHEN @P6 = 5 THEN AccTafID5 WHEN @P6 = 6 THEN AccTafID6
																END
					
	  END 
		*/
    ------------------------------------------------------------------------		 
		/*SELECT    FinancialPeriodID,FinancialPeriodName,  DocStateID ,   DocStateName ,  BranchCode ,  BrchName  
		FROM 
				(	SELECT  FinancialPeriodID,FinancialPeriodName,NULL  DocStateID , NULL  DocStateName , NULL BranchCode ,NULL  BrchName  
					FROM dbo.FinancialPeriod
					WHERE FinancialPeriodID IN (@FinancialPeriodIDFrom   ,	@FinancialPeriodIDTo    )
		
					UNION ALL 
		
					SELECT  NULL FinancialPeriodID,NULL FinancialPeriodName,  DocStateID ,   DocStateName , NULL BranchCode ,NULL  BrchName   
					FROM dbo.AccDocState
					WHERE DocStateID IN (SELECT DocStateID FROM @AccDocState)
		
					UNION ALL 
		
					SELECT  NULL FinancialPeriodID,NULL FinancialPeriodName, NULL   DocStateID , NULL   DocStateName ,  BranchCode ,  BrchName   
					FROM dbo.Branches
					WHERE BranchCode IN (SELECT BrchCode FROM @BranchList )
			 )P*/
		-----------------------------------------------------------------------------------
	  DECLARE @FinancialPeriodIDFromName   NVARCHAR(100)				       ,@FinancialPeriodIDToName             NVARCHAR(100),
		        @DocStateNameList            NVARCHAR(1000)              ,@BranchNameList                      NVARCHAR(1000)

		SET @FinancialPeriodIDFromName = (SELECT FinancialPeriodName  FROM dbo.FinancialPeriod  WHERE FinancialPeriodID = @FinancialPeriodIDFrom)
		SET @FinancialPeriodIDToName   = (SELECT FinancialPeriodName  FROM dbo.FinancialPeriod  WHERE FinancialPeriodID = @FinancialPeriodIDTo  )
		SET @DocStateNameList          = (SELECT DocStateName FROM dbo.AccDocState WHERE DocStateID IN (SELECT DocStateID FROM @AccDocState)  OR @AccDocStateList IS NULL 
		                                  FOR JSON PATH 
																			)
		SET @BranchNameList            = (SELECT BrchName FROM dbo.Branches   WHERE BranchCode IN (SELECT BrchCode FROM @BranchList) OR @BranchCodeList IS NULL 
		                                  FOR JSON PATH 
																			)
    DECLARE @TakeDate   DATE , @TakeReportDate NCHAR(10)
		SET     @TakeDate = GETDATE()
    SET @TakeReportDate = (SELECT dbo.DateConvertion(@TakeDate,'m2s'))
		SELECT @FinancialPeriodIDFromName  ,@FinancialPeriodIDToName , @DocStateNameList , isnull(@BranchNameList ,'[]'), @TakeReportDate TakeReportDate
  	-----------------------------------------------------------------------------------------
		--SELECT COUNT(*) RowNo FROM @CodingList 
		-----------------------------------------------------------------------------------------
		IF (select count(*)  from  @AccPriority) =0
		BEGIN 
		    INSERT INTO @AccPriority  (RowNo,AccKind,AccKindCodeName,AccKindName )
			  VALUES                    (1,3,'MoeenCode', 'MoeenName')
				--SET @P1  = 'MoeenCode' 
				--SET @PN1 = 'MoeenName'
	  END
		IF @DelRow IS NOT NULL 
				INSERT INTO @AccPriority
		               ( RowNo     , AccKind , AccKindCodeName , AccKindName)
 	      VALUES     ( @MaxRow   , @DelRow , @DelRowKindName , @DelRowName)
		SELECT * FROM @AccPriority
		-----------------------------------------------------------------------------------------
							/*SELECT  CASE WHEN @U = 3 THEN Moeencode END,
        SUM(AccDocDtlAmount) TAD
FROM dbo.VWAccMTMapDetail INNER JOIN dbo.AccDocDetail ON AccDocDetail.AccMTMapID = VWAccMTMapDetail.AccMTMapID
GROUP BY CASE WHEN @U = 3 THEN Moeencode END  */
							 								 

		 
END
