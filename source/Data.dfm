object DataModule1: TDataModule1
  OnCreate = DataModuleCreate
  Height = 1080
  Width = 1440
  PixelsPerInch = 144
  object connection: TFDConnection
    Params.Strings = (
      'DriverID=SQLite')
    Left = 45
    Top = 35
  end
  object query: TFDQuery
    Connection = connection
    Left = 180
    Top = 35
  end
  object FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink
    Left = 45
    Top = 155
  end
end
