#import "TNoodle.h"

#import "org/worldcubeassociation/tnoodle/scrambles/PuzzleRegistry.h"
#import "org/worldcubeassociation/tnoodle/scrambles/Puzzle.h"
#import "org/worldcubeassociation/tnoodle/svglite/Svg.h"
#import "java/util/Random.h"

// Resolves the Java scrambler for `puzzle`, or nil when the raw value has no
// `PuzzleRegistry` counterpart (e.g. a header newer than the linked library)
// or the scrambler could not be instantiated.
static OrgWorldcubeassociationTnoodleScramblesPuzzle *_Nullable TNoodleScramblerFor(TNoodlePuzzle puzzle) {
  OrgWorldcubeassociationTnoodleScramblesPuzzleRegistry *reg =
    OrgWorldcubeassociationTnoodleScramblesPuzzleRegistry_fromOrdinal((OrgWorldcubeassociationTnoodleScramblesPuzzleRegistry_ORDINAL)puzzle);

  return [reg getScrambler];
}

static NSString *TNoodleUnsupportedPuzzleError(TNoodlePuzzle puzzle) {
  return [NSString stringWithFormat:@"<TNoodle error: unsupported puzzle %d>", (int)puzzle];
}

@implementation TNoodle

+ (NSString *)generateWcaScramble:(TNoodlePuzzle)puzzle seed:(int64_t)seed {
  @try {
    OrgWorldcubeassociationTnoodleScramblesPuzzle *scrambler = TNoodleScramblerFor(puzzle);
    if (scrambler == nil) {
      return TNoodleUnsupportedPuzzleError(puzzle);
    }

    JavaUtilRandom *r = [[JavaUtilRandom alloc] initWithLong:seed];

    return [scrambler generateWcaScrambleWithJavaUtilRandom:r];
  }
  @catch (NSException *ex) {
    return [NSString stringWithFormat:@"<TNoodle error: %@>", ex.reason ?: @"unknown"];
  }
}

+ (NSString *)drawScramble:(TNoodlePuzzle)puzzle
                  scramble:(nullable NSString *)scramble
               colorScheme:(nullable NSString *)colorScheme {
  @try {
    OrgWorldcubeassociationTnoodleScramblesPuzzle *scrambler = TNoodleScramblerFor(puzzle);
    if (scrambler == nil) {
      return TNoodleUnsupportedPuzzleError(puzzle);
    }

    id<JavaUtilMap> parsedColorScheme = [scrambler parseColorSchemeWithNSString:colorScheme];

    if (colorScheme != nil && colorScheme.length > 0 && parsedColorScheme == nil) {
      return @"<TNoodle error: invalid color scheme>";
    }

    OrgWorldcubeassociationTnoodleSvgliteSvg *svg =
      [scrambler drawScrambleWithNSString:scramble withJavaUtilMap:parsedColorScheme];

    return [svg description];
  }
  @catch (NSException *ex) {
    return [NSString stringWithFormat:@"<TNoodle error: %@>", ex.reason ?: @"unknown"];
  }
}

@end
