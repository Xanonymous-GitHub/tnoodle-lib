#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int32_t, TNoodlePuzzle) {
  TNoodlePuzzleTwo      = 0,
  TNoodlePuzzleThree    = 1,
  TNoodlePuzzleFour     = 2,
  TNoodlePuzzleFourFast = 3,
  TNoodlePuzzleFive     = 4,
  TNoodlePuzzleSix      = 5,
  TNoodlePuzzleSeven    = 6,
  TNoodlePuzzleThreeNI  = 7,
  TNoodlePuzzleFourNI   = 8,
  TNoodlePuzzleFiveNI   = 9,
  TNoodlePuzzleThreeFM  = 10,
  TNoodlePuzzlePyra     = 11,
  TNoodlePuzzleSq1      = 12,
  TNoodlePuzzleMega     = 13,
  TNoodlePuzzleClock    = 14,
  TNoodlePuzzleSkewb    = 15,
};

@interface TNoodle : NSObject

+ (NSString *)generateWcaScramble:(TNoodlePuzzle)puzzle seed:(int64_t)seed;

@end

NS_ASSUME_NONNULL_END
