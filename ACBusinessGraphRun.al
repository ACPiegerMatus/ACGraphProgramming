codeunit 50122 "ACBusinessGraphRun"
{
    //Typ codeunity je install - vlozeni do web klienta
    Subtype = Install;

    //Po prelozeni appky se vlozi naprogramovany graf z codeunity Demo Char ManagementAC
    trigger OnInstallAppPerCompany()
    var
        ChartMgt: Codeunit "ACBusinessGraph";
    begin
        //Volani funkce pro vlozeni navrzeneho grafu
        ChartMgt.InstallChart();
    end;
}