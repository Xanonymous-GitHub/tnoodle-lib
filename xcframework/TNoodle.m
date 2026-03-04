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

+ (OrgWorldcubeassociationTnoodleSvgliteSvg *)drawScramble:(TNoodlePuzzle)puzzle
                                                  scramble:(NSString *)scramble
                                               colorScheme:(id<JavaUtilMap>)colorScheme {
  OrgWorldcubeassociationTnoodleScramblesPuzzleRegistry *reg =
    OrgWorldcubeassociationTnoodleScramblesPuzzleRegistry_fromOrdinal((OrgWorldcubeassociationTnoodleScramblesPuzzleRegistry_ORDINAL)puzzle);

  OrgWorldcubeassociationTnoodleScramblesPuzzle *scrambler = [reg getScrambler];
  return [scrambler drawScrambleWithNSString:scramble withJavaUtilMap:colorScheme];
}

@end
