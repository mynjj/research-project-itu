page 50120 Directors
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = Directors;

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                }
                field("IMDB Link"; Rec."IMDB Link")
                {
                    ApplicationArea = All;
                }
            }
        }
        area(Factboxes)
        {

        }
    }

    actions
    {
        area(Processing)
        {
            action(RandomDirector)
            {
                ApplicationArea = All;

                trigger OnAction();
                var
                    Director: Record "Directors";
                    Name: Text[2048];
                begin
                    Director.Init();
                    Director.Name := DirectorsMgt.RandomDirectorName();
                    Director.Insert(true);
                end;
            }
        }
    }

    var
        DirectorsMgt: Codeunit DirectorsMgt;
}