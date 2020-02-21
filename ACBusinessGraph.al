codeunit 50140 "ACBusinessGraph"
{
    var
        ChartDescriptionMsg: Label 'Graf vývoje prodeje';
        ChartNameLbl: Label 'Graf vývoje prodeje';
        StatusPeriodLengthTxt: Label 'Vývoj prodeje | Pohled za %1';
        MeasureNameTxt: Label 'Počet objednávek';
        day: Integer;
        week: Integer;
        month: Integer;
        year: Integer;

    //Funkce pro inicializaci grafu
    procedure InstallChart()
    var
        ChartDefinition: Record "Chart Definition"; //Vytahneme zaznam z tabulky Chart Definition
    begin
        if not ChartDefinition.Get(Codeunit::"ACBusinessGraph", ChartNameLbl) then begin
            ChartDefinition."Code Unit ID" := Codeunit::"ACBusinessGraph";
            ChartDefinition."Chart Name" := ChartNameLbl;
            ChartDefinition.Enabled := true;
            ChartDefinition.Insert(true);
        end;
    end;

    //EventSubscriber pro popis grafu
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Chart Management", 'OnBeforeChartDescription', '', true, true)]
    local procedure ChartManagementOnChartDescriptionSubscriber(ChartDefinition: Record "Chart Definition"; var ChartDescription: Text; var IsHandled: Boolean)
    begin
        case ChartDefinition."Code Unit ID" of
            Codeunit::"ACBusinessGraph":
                begin
                    //Zde vlozime popis grafu z globalni promenne
                    ChartDescription := ChartDescriptionMsg;
                    IsHandled := true;
                end;
        end;
    end;

    //EventSubscriber pro rozkliknuti
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Chart Management", 'OnBeforeDataPointClicked', '', true, true)]
    local procedure ChartManagementOnDataPointClickedSubscriber(var ChartDefinition: Record "Chart Definition"; var BusinessChartBuffer: Record "Business Chart Buffer"; var IsHandled: Boolean)
    begin
        case ChartDefinition."Code Unit ID" of
            Codeunit::"ACBusinessGraph":
                begin
                    Message('Drill Down');
                    IsHandled := true;
                end;
        end;
    end;

    //Eventsubscriber pro samotne vlozeni grafu
    //Pokud je Chart definition prazdny,zavola se funkce Installchart
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Chart Management", 'OnAfterPopulateChartDefinitionTable', '', true, true)]
    local procedure ChartManagementOnPopulateChartDefinitionTable()
    begin
        InstallChart();
    end;

    //Tento Event se zavola v pripade ze se zmeni delky periody v grafu
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Chart Management", 'OnBeforeSetPeriodLength', '', true, true)]
    local procedure ChartManagementOnSetPeriodLengthSubscriber(ChartDefinition: Record "Chart Definition"; PeriodLength: Option; var IsHandled: Boolean)
    var
        BusChartBuf: Record "Business Chart Buffer";
    begin
        case ChartDefinition."Code Unit ID" of
            Codeunit::"ACBusinessGraph":
                begin
                    BusChartBuf."Period Length" := PeriodLength;
                    SaveSettings(BusChartBuf);
                    IsHandled := true;
                end;
        end;
    end;

    //EventSubscriber pro aktualizaci grafu
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Chart Management", 'OnBeforeUpdateChart', '', true, true)]
    local procedure ChartManagementOnUpdateChartSubscriber(var ChartDefinition: Record "Chart Definition"; var BusinessChartBuffer: Record "Business Chart Buffer"; Period: Option; var IsHandled: Boolean)
    begin
        case ChartDefinition."Code Unit ID" of
            Codeunit::"ACBusinessGraph":
                begin
                    UpdateChart(BusinessChartBuffer, 0);
                    UpdateLastUsedChart(ChartDefinition);
                    IsHandled := true;
                end;
        end;
    end;

    //Event,ve kterem muzeme definovat akce,ktere se odehraji po kliknuti na prev/next
    //skok na predesly/dalsi graf
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Chart Management", 'OnBeforeUpdateNextPrevious', '', true, true)]
    local procedure ChartManagementOnUpdateNextPreviousSubscriber(var ChartDefinition: Record "Chart Definition"; var Result: Boolean; var IsHandled: Boolean)
    begin
        Case ChartDefinition."Code Unit ID" of
            Codeunit::"ACBusinessGraph":
                begin
                    IsHandled := true;
                    Result := true;
                end;
        end;
    end;

    //Event, ktery updatuje nazev grafu a jeho periodu
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Chart Management", 'OnBeforeUpdateStatusText', '', true, true)]
    local procedure ChartManagementOnUpdateStatusTextSubscriber(ChartDefinition: Record "Chart Definition"; BusinessChartBuffer: Record "Business Chart Buffer"; var StatusText: Text; var IsHandled: Boolean)
    begin
        case ChartDefinition."Code Unit ID" of
            Codeunit::"ACBusinessGraph":
                begin
                    StatusText := UpdateStatusText(BusinessChartBuffer);
                    IsHandled := true;
                end;
        end;
    end;

    //Kdyz si uzivatel vybere graf,spusti se tento event aby ziskal nastaveni pro dany graf
    [EventSubscriber(ObjectType::Page, Page::"Help And Chart Wrapper", 'OnBeforeInitializeSelectedChart', '', true, true)]
    local procedure HelpAndChartWrapperOnBeforeInitializeSelectedChartSubscriber(var ChartDefinition: Record "Chart Definition")
    var
        PeriodLength: Option;
    begin
        case ChartDefinition."Code Unit ID" of      //Pokud je ID codeunity stejne jako DemoChartManagement...
            Codeunit::"ACBusinessGraph":
                GetSettings(PeriodLength);          // Ziskame nastaveni
        end;
    end;

    // Funkce pro ulozeni nastaveni vytvareneho grafu
    local procedure SaveSettings(BusChartBuf: Record "Business Chart Buffer")
    var
        BusChartUserSetup: Record "Business Chart User Setup";
    begin
        // Do setupu grafu vlozime hodnotu Period Length z bufferu
        BusChartUserSetup."Period Length" := BusChartBuf."Period Length";
        // Zavolame funkci SaveSetupCU, ktera si ulozi setup grafu a prislusnou codeunitu
        BusChartUserSetup.SaveSetupCU(BusChartUserSetup, Codeunit::"ACBusinessGraph");
    end;

    local procedure GetSettings(var PeriodLength: Option)
    var
        BusChartUserSetup: Record "Business Chart User Setup";
    begin
        // Pokud neni prihlaseny uzivatel, vlozime do Period Length option "Mesic"
        if not BusChartUserSetup.Get(UserId(), ObjectType::Codeunit, Codeunit::"ACBusinessGraph") then
            BusChartUserSetup."Period Length" := BusChartUserSetup."Period Length"::Month;

        BusChartUserSetup.InitSetupCU(Codeunit::"ACBusinessGraph");
        PeriodLength := BusChartUserSetup."Period Length";
    end;

    local procedure UpdateLastUsedChart(ChartDefinition: Record "Chart Definition")
    var
        LastUsedChart: Record "Last Used Chart";    // Zde by melo byt ulozene ID a codeunita
                                                    // posledniho grafu
    begin
        with LastUsedChart do
            // Pokud uz mame nalogovaneho uzivatele tak se graf jenom zmeni
            if Get(UserId()) then begin
                Validate("Code Unit ID", ChartDefinition."Code Unit ID");
                Validate("Chart Name", ChartDefinition."Chart Name");
                Modify();
            end else begin
                // Pokud uzivatel jeste neni prihlaseny, prida se prvni graf
                Validate(UID, UserId());
                Validate("Code Unit ID", ChartDefinition."Code Unit ID");
                Validate("Chart Name", ChartDefinition."Chart Name");
                Insert();
            end;
    end;

    //Status text je text,ktery popisuje graf
    //Nachazi se zde udaj o nazvu grafu a aktualni periode grafu 
    local procedure UpdateStatusText(BusChartBuf: Record "Business Chart Buffer"): Text
    var
        StatusText: Text;   // Lokalni promenna, do ktere ulozime nastaveni textu pro popis grafu
    begin
        // Vychazi ze: StatusPeriodLengthTxt: Label 'Demo graf | Pohled za %1';
        StatusText := StrSubstNo(StatusPeriodLengthTxt, Format(BusChartBuf."Period Length"));

        exit(StatusText);
    end;

    // Hlavni funkce pro nastaveni grafu
    // Funkce pridava columns (sloupce) a measurements (jednotky)
    local procedure UpdateChart(var BusChartBuf: Record "Business Chart Buffer"; Period: Option " ",Next,Previous)
    var
        BusChartMapColumn: Record "Business Chart Map";
        SalesOrder: Record "Sales Header";
        PeriodLength: Text[1];
        NoOfPeriods: Integer;
        PeriodCounter: Integer;
        FromDate: Date;
        ToDate: Date;
        hodnota: Integer;
        DataType: Option;

    begin
        // any settings stored for this chart - we are only storing the periods that are used.
        GetSettings(BusChartBuf."Period Length");

        with BusChartBuf do begin
            if Period = Period::" " then begin
                FromDate := 0D;
                ToDate := 0D;
            end else
                if FindMidColumn(BusChartMapColumn) then
                    GetPeriodFromMapColumn(BusChartMapColumn.Index, FromDate, ToDate);

            // now we are initializing the chart and defining the X axis for it - here it is a period of time
            Initialize();
            //SetPeriodXAxis();
            //Pro odstraneni konkretniho casu pri dnech
            DataType := "Data Type"::String;
            SetXAxis(Format("Period Length"), DataType);

            InitParameters(BusChartBuf, PeriodLength, NoOfPeriods);
            CalcAndInsertPeriodAxis(BusChartBuf, Period, NoOfPeriods, FromDate, ToDate);
            //Pro pridani dalsi polozky v jednom sloupci grafu
            AddMeasure(MeasureNameTxt, '', "Data Type"::Decimal, "Chart Type"::StackedColumn);
            month := Date2DMY(WorkDate(), 2);
            day := Date2DMY(WorkDate(), 1);
            year := Date2DMY(WorkDate(), 3);
            week := DATE2DWY(WorkDate(), 2);

            // we are now defining the Y axis values for each of the measures for each of the periods. Since it's just a demo
            FindFirstColumn(BusChartMapColumn);
            //Prvni for je pro preskakovani mezi sloupcemi
            for PeriodCounter := 1 to NoOfPeriods do begin
                GetPeriodFromMapColumn(PeriodCounter - 1, FromDate, ToDate);

                case BusChartBuf."Period Length" of
                    BusChartBuf."Period Length"::Day:
                        begin
                            SalesOrder.SetRange("Document Type", SalesOrder."Document Type"::Order);
                            SalesOrder.SetRange("Order Date", DMY2Date(day, month, year), DMY2Date(day, month, year));
                            hodnota := SalesOrder.Count();
                            //Nazev a cislo, poradi/index sloupce,hodnota sloupce)
                            SetValue(MeasureNameTxt, NoOfPeriods - PeriodCounter, hodnota);
                            day := day - 1;
                            if (day = 0) then begin
                                month := month - 1;
                                GetCorrectDayCount();
                                if (month = 0) then begin
                                    month := 12;
                                    year := year - 1;
                                    GetCorrectDayCount();
                                end;
                            end;
                        end;

                    BusChartBuf."Period Length"::Week:
                        if (week = 1) then begin
                            year := year - 1;
                            week := 53;
                            SalesOrder.SetRange("Document Type", SalesOrder."Document Type"::Order);
                            SalesOrder.SetRange("Order Date", DWY2Date(1, week, year), DWY2Date(7, week, year));
                            hodnota := SalesOrder.Count();
                            SetValue(MeasureNameTxt, NoOfPeriods - PeriodCounter, hodnota);
                        end else begin
                            SalesOrder.SetRange("Document Type", SalesOrder."Document Type"::Order);
                            SalesOrder.SetRange("Order Date", DWY2Date(1, week, year), DWY2Date(7, week, year));
                            hodnota := SalesOrder.Count();
                            SetValue(MeasureNameTxt, NoOfPeriods - PeriodCounter, hodnota);
                            week := week - 1;
                        end;

                    BusChartBuf."Period Length"::Month:
                        begin
                            SalesOrder.SetRange("Document Type", SalesOrder."Document Type"::Order);
                            GetCorrectDayCount();
                            if (month = 0) then begin
                                month := 12;
                                year := year - 1;
                                GetCorrectDayCount();
                                SalesOrder.SetRange("Order Date", DMY2Date(1, month, year), DMY2Date(day, month, year));
                                hodnota := SalesOrder.Count();
                                SetValue(MeasureNameTxt, NoOfPeriods - PeriodCounter, hodnota);
                                month := month - 1
                            end else begin
                                SalesOrder.SetRange("Order Date", DMY2Date(1, month, year), DMY2Date(day, month, year));
                                hodnota := SalesOrder.Count();
                                SetValue(MeasureNameTxt, NoOfPeriods - PeriodCounter, hodnota);
                                month := month - 1;
                            end;
                        end;

                    BusChartBuf."Period Length"::Quarter:
                        begin
                            SalesOrder.SetRange("Document Type", SalesOrder."Document Type"::Order);
                            if ((month > 0) and (month < 4)) then begin      //Q1
                                SalesOrder.SetRange("Order Date", DMY2Date(1, 1, year), DMY2Date(31, 3, year));
                                hodnota := SalesOrder.Count();
                                SetValue(MeasureNameTxt, NoOfPeriods - PeriodCounter, hodnota);
                            end;
                            if ((month > 3) and (month < 7)) then begin      //Q2
                                SalesOrder.SetRange("Order Date", DMY2Date(1, 4, year), DMY2Date(30, 6, year));
                                hodnota := SalesOrder.Count();
                                SetValue(MeasureNameTxt, NoOfPeriods - PeriodCounter, hodnota);
                            end;
                            if ((month > 6) and (month < 10)) then begin     //Q3
                                SalesOrder.SetRange("Order Date", DMY2Date(1, 7, year), DMY2Date(30, 9, year));
                                hodnota := SalesOrder.Count();
                                SetValue(MeasureNameTxt, NoOfPeriods - PeriodCounter, hodnota);
                            end;
                            if ((month > 9) and (month < 13)) then begin     //Q4
                                SalesOrder.SetRange("Order Date", DMY2Date(1, 10, year), DMY2Date(31, 12, year));
                                hodnota := SalesOrder.Count();
                                SetValue(MeasureNameTxt, NoOfPeriods - PeriodCounter, hodnota);
                            end;
                            month := month - 3;
                            if (month <= 0) then year := year - 1;
                            if (month = 0) then month := 12;
                            if (month = -1) then month := 11;
                            if (month = -2) then month := 10;
                        end;

                    BusChartBuf."Period Length"::Year:
                        begin
                            SalesOrder.SetRange("Document Type", SalesOrder."Document Type"::Order);
                            SalesOrder.SetRange("Order Date", DMY2Date(1, 1, year), DMY2Date(31, 12, year));
                            hodnota := SalesOrder.Count();
                            SetValue(MeasureNameTxt, NoOfPeriods - PeriodCounter, hodnota);
                            year := year - 1;
                        end;
                end;
            end;
        end;
    end;

    // Inicializace parametru
    // PeriodLength - dostaneme delku periody
    // NoOfPeriods - pocet period v grafu
    local procedure InitParameters(BusChartBuf: Record "Business Chart Buffer"; var PeriodLength: Text[1]; var NoOfPeriods: Integer)
    begin
        PeriodLength := GetPeriod(BusChartBuf);          //Vrati kod periody napr. "M"
        NoOfPeriods := GetNoOfPeriods(BusChartBuf);     // Z lokalni funkce vytahneme pocet period
    end;

    // Funkce, ktera vrati delku periody grafu
    local procedure GetPeriod(BusChartBuf: Record "Business Chart Buffer"): Text[1]
    begin
        // Pokud je delka periody v bufferu nastaveni grafu prazdna,vrati defaultne Mesice "M"
        if BusChartBuf."Period Length" = BusChartBuf."Period Length"::None then
            exit('M');
        exit(BusChartBuf.GetPeriodLength());      // Vrati hodnotu periody ulozenou v bufferu 
    end;

    // Funkce, ktera vrati pocet period grafu
    local procedure GetNoOfPeriods(BusChartBuf: Record "Business Chart Buffer"): Integer
    var
        NoOfPeriods: Integer;                     // Promenna pro pocet period
    begin
        NoOfPeriods := 14;
        // Case struktura kde expression je delka periody (option)
        case BusChartBuf."Period Length" of     // TADY je expression
            BusChartBuf."Period Length"::Day:   // Pokud je v Period Length option "Den"
                NoOfPeriods := 16;              //Tak je pocet period rovny 16
            BusChartBuf."Period Length"::Week,
            BusChartBuf."Period Length"::Quarter:   // Pokud je Period Length option "Tyden" nebo "Ctvrtrok"
                NoOfPeriods := 12;              // Jinak je pocet period 14
            BusChartBuf."Period Length"::Month:     // Pokud je Period Length option "Mesic"
                NoOfPeriods := 12;              // Jinak bude rovny 12
            BusChartBuf."Period Length"::Year:      // Pokud je Period Length option "Rok"
                NoOfPeriods := 7;               // Jinak bude rovny 7
            BusChartBuf."Period Length"::None:      // Pokud v Period Length nemame nic
                NoOfPeriods := 7;                   // Pocet peroid bude rovny 7
        end;
        exit(NoOfPeriods);                          // Vrati pocet period
    end;

    local procedure CalcAndInsertPeriodAxis(var BusChartBuf: Record "Business Chart Buffer"; Period: Option " ",Next,Previous; MaxPeriodNo: Integer; StartDate: Date; EndDate: Date)
    var
        PeriodDate: Date;
    begin
        if (StartDate = 0D) and (BusChartBuf."Period Filter Start Date" <> 0D) then
            PeriodDate := CalcDate(StrSubstNo('<-1%1>', BusChartBuf.GetPeriodLength()), BusChartBuf."Period Filter Start Date")
        else begin
            BusChartBuf.RecalculatePeriodFilter(StartDate, EndDate, Period);
            PeriodDate := CalcDate(StrSubstNo('<-%1%2>', MaxPeriodNo, BusChartBuf.GetPeriodLength()), EndDate);
        end;

        BusChartBuf.AddPeriods(GetCorrectedDate(BusChartBuf, PeriodDate, 1), GetCorrectedDate(BusChartBuf, PeriodDate, MaxPeriodNo));
    end;

    local procedure GetCorrectedDate(BusChartBuf: Record "Business Chart Buffer"; InputDate: Date; PeriodNo: Integer) OutputDate: Date
    begin
        OutputDate := CalcDate(StrSubstNo('<%1%2>', PeriodNo, BusChartBuf.GetPeriodLength()), InputDate);
        if BusChartBuf."Period Length" <> BusChartBuf."Period Length"::Day then
            OutputDate := CalcDate(StrSubstNo('<C%1>', BusChartBuf.GetPeriodLength()), OutputDate);
    end;

    local procedure GetCorrectDayCount()
    begin
        if ((month = 1) or (month = 3) or (month = 5) or (month = 7) or (month = 8) or (month = 10) or (month = 12)) then
            day := 31
        else
            if ((month = 4) or (month = 6) or (month = 9) or (month = 11)) then
                day := 30
            else
                if ((month = 2)) then begin
                    if ((month MOD 4) = 0) then begin
                        if ((month MOD 100) = 0) then
                            day := 29
                        else
                            day := 28;
                    end else
                        day := 28;
                end else
                    day := 28;
    end;
}