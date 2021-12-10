codeunit 50150 DirectorsTests
{
    Subtype = Test;

    trigger OnRun()
    begin
    end;

    var
        Assert: Codeunit "Assert";
        LibraryUtility: Codeunit "Library - Utility";

    [Test]
    procedure CantCreateDirectorWithNoName()
    var
        Directors: Record "Directors";
    begin
        Directors.Init();
        asserterror Directors.Insert(true);
    end;

    [Test]
    procedure CreatingDirectorWithDefaults()
    var
        Directors: Record "Directors";
    begin
        Directors.Init();
        Directors.Name := LibraryUtility.GenerateRandomText(100);
        Directors.Insert(true);
        Assert.AreNotEqual('', Directors."IMDB Link", 'A default value for IMDB link was not added.');
    end;

}