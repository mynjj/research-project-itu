table 50101 Directors
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
        field(3; "IMDB Link"; Text[2048])
        {
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(Key1; Id)
        {
            Clustered = true;
        }
    }

    trigger onInsert()
    begin
        Validate(Rec.Name);

        if Rec."IMDB Link" = '' then
            Rec."IMDB Link" := 'https://imdb.com/' + Rec.Name;

        if IsNullGuid(Rec.Id) then
            Rec.Id := CreateGuid();
    end;

}