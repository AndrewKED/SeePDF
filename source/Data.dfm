object DataModule1: TDataModule1
  OnCreate = DataModuleCreate
  Height = 720
  Width = 960
  object connection: TFDConnection
    Params.Strings = (
      'DriverID=SQLite')
    Left = 30
    Top = 23
  end
  object query: TFDQuery
    Connection = connection
    Left = 120
    Top = 23
  end
  object FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink
    Left = 30
    Top = 103
  end
end
