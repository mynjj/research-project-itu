codeunit 50140 DirectorsMgt
{
    trigger OnRun()
    begin
    end;

    procedure RandomDirectorName(): Text[2048]
    var
        DiText: Text;
    begin
        DiText := 'Cuaron';
        exit(DiText);
    end;
}