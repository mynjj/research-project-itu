codeunit 50140 DirectorsMgt
{
    trigger OnRun()
    begin
    end;

    procedure RandomDirectorName(): Text[2048]
    begin
        exit('Tarantino');
    end;
}