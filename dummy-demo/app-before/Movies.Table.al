table 50100 Movies
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; Id; Guid)
        {
            DataClassification = CustomerContent;
        }
        field(2; Name; Text[2048])
        {
            DataClassification = CustomerContent;
            trigger OnValidate()
            begin
                Rec.TestField(Name);
            end;
        }
        field(3; DirectorId; Guid)
        {
            DataClassification = CustomerContent;
            TableRelation = Directors.Id where(Id = field(DirectorId));
        }
    }

    keys
    {
        key(Key1; Id)
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    begin
        Validate(Rec.Name);

        if IsNullGuid(Rec.Id) then
            Rec.Id := CreateGuid();
    end;

}