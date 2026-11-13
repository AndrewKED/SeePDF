unit Constants;

interface

const
  ORIGINATOR = 'KED';
  PROGRAM_NAME = 'SeePDF';

  TBL_SCORES = 'scores';
  TBL_AUDIO = 'audio';

type
  TTuneType = (
    TYPE_OTHER = 0,
    TYPE_MARCH = 1,
    TYPE_STRATHSPEY = 2,
    TYPE_REEL = 3,
    TYPE_SLOW_AIR = 4,
    TYPE_HORNPIPE = 5,
    TYPE_JIG = 6,
    TYPE_POLKA = 7,
    TYPE_WALTZ = 8,
    TYPE_MIXED = 9,
    TYPE_SLOW_MARCH = 10
  );

  TTuneInfo = record
    id : TTuneType;
    name : String;
  end;

const
  TUNE_TYPES : array[0..10] of TTuneInfo = (
     (id: TYPE_OTHER;     name: 'Other/Not indicated'),
     (id: TYPE_HORNPIPE;     name: 'Hornpipe'),
     (id: TYPE_JIG;     name: 'Jig'),
     (id: TYPE_MARCH;     name: 'March'),
     (id: TYPE_MIXED;     name: 'Mixed'),
     (id: TYPE_POLKA;     name: 'Polka'),
     (id: TYPE_REEL;     name: 'Reel'),
     (id: TYPE_SLOW_AIR;     name: 'Slow Air'),
     (id: TYPE_SLOW_MARCH;  name: 'Slow march'),
     (id: TYPE_STRATHSPEY;     name: 'Strathspey'),
     (id: TYPE_WALTZ;     name: 'Waltz')
  );

implementation

end.
