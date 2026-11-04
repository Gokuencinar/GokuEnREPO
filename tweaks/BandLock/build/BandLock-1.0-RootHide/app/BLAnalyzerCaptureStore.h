#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BLAnalyzerCaptureStore : NSObject
+ (NSArray<NSDictionary *> *)captures;
+ (nullable NSURL *)URLForCapture:(NSDictionary *)capture;
+ (nullable NSDictionary *)saveImage:(UIImage *)image
                                 mode:(NSString *)mode
                         operatorName:(nullable NSString *)operatorName
                                error:(NSError * _Nullable * _Nullable)error;
+ (BOOL)deleteCapture:(NSDictionary *)capture error:(NSError * _Nullable * _Nullable)error;
+ (NSString *)displayMode:(NSString *)mode;
+ (NSString *)displayTitleForCapture:(NSDictionary *)capture;
@end

NS_ASSUME_NONNULL_END
