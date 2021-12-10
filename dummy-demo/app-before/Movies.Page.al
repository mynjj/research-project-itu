page 50121 Movies
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = Movies;

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field(Name; Name)
                {
                    ApplicationArea = All;
                }
                field(Director; DirectorId)
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
            action(ActionName)
            {
                ApplicationArea = All;

                trigger OnAction();
                begin

                end;
            }
        }
    }
}