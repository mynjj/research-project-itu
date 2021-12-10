codeunit 50151 MoviesTests
{
    Subtype = Test;

    trigger OnRun()
    begin
    end;

    [Test]
    procedure CantCreateMovieWithNoName()
    var
        Movies: Record "Movies";
    begin
        Movies.Init();
        asserterror Movies.Insert(true);
    end;
}