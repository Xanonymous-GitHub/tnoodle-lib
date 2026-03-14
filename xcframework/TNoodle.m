#import "TNoodle.h"

#import "org/worldcubeassociation/tnoodle/scrambles/PuzzleRegistry.h"
#import "org/worldcubeassociation/tnoodle/scrambles/Puzzle.h"
#import "org/worldcubeassociation/tnoodle/svglite/Svg.h"
#import "java/util/Random.h"

@implementation TNoodle

+ (NSString *)generateWcaScramble:(TNoodlePuzzle)puzzle seed:(int64_t)seed {
  @try {
    JavaUtilRandom *r = [[JavaUtilRandom alloc] initWithLong:seed];

    OrgWorldcubeassociationTnoodleScramblesPuzzleRegistry *reg =
      OrgWorldcubeassociationTnoodleScramblesPuzzleRegistry_fromOrdinal((OrgWorldcubeassociationTnoodleScramblesPuzzleRegistry_ORDINAL)puzzle);

    OrgWorldcubeassociationTnoodleScramblesPuzzle *scrambler = [reg getScrambler];

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
    OrgWorldcubeassociationTnoodleScramblesPuzzleRegistry *reg =
      OrgWorldcubeassociationTnoodleScramblesPuzzleRegistry_fromOrdinal((OrgWorldcubeassociationTnoodleScramblesPuzzleRegistry_ORDINAL)puzzle);

    OrgWorldcubeassociationTnoodleScramblesPuzzle *scrambler = [reg getScrambler];
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
