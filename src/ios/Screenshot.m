//
// Screenshot.h
//
// Created by Simon Madine on 29/04/2010.
// Copyright 2010 The Angry Robot Zombie Factory.
// - Converted to Cordova 1.6.1 by Josemando Sobral.
// MIT licensed
//
// Modifications to support orientation change by @ffd8
//

#import <Cordova/CDV.h>
#import "Screenshot.h"
#import <Photos/Photos.h>

@interface Screenshot()
    
    typedef enum
    {
        ScreenshotStepMakeAlbum,
        ScreenshotStepAddResource,
        ScreenshotStepGetResource,
        ScreenshotStepGetUrl,
        ScreenshotStepRendering,
        ScreenshotStepWaiting,
        ScreenshotStepTesting,
        ScreenshotStepFinish
    } ScreenshotSteps;
    
    @property ScreenshotSteps step;
    @property PHAssetCollection *currentAlbum;
    @property NSString *identifierResource;
    @property PHAsset *currentAsset;
    @property NSString *path;
    @property BOOL running;
    @property NSDictionary *result;
    @end

@implementation Screenshot
    
    
    @synthesize webView;
    
    - (UIImage *)getScreenshot
    {
        UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
        CGRect rect = [keyWindow bounds];
        UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0);
        [keyWindow drawViewHierarchyInRect:keyWindow.bounds afterScreenUpdates:NO];
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return img;
    }
    
    - (void)saveScreenshot:(CDVInvokedUrlCommand*)command
    {
        NSString *albumName =  [[command arguments] count] > 2 ? [[command arguments] objectAtIndex:2] : NULL;
        
        if (albumName == nil || [albumName isEqualToString:@""])
        {
            albumName = @"Cordova Screenshot";
        }
        
        UIImage *image = [self getScreenshot];
        
        __block Screenshot* this = self;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            [this setStep:ScreenshotStepTesting];
            [this setCurrentAlbum:nil];
            [this setCurrentAsset:nil];
            [this setIdentifierResource:nil];
            [this setResult:nil];
            [this setPath:nil];
            
            [this setRunning:YES];
            int count = 0;
            BOOL firtTime = YES;
            while ([this running])
            {
                //NSLog(@" %i", count++);
                
                switch ([this step]) {
                    case ScreenshotStepTesting:
                    {
                        NSLog(@"ScreenshotStepTesting...");
                        if([PHPhotoLibrary authorizationStatus] == AVAuthorizationStatusAuthorized)
                        {
                            if (![this currentAlbum])
                            {
                                [this setStep:ScreenshotStepMakeAlbum];
                            }
                            else if(![this identifierResource])
                            {
                                [this setStep:ScreenshotStepAddResource];
                            }
                            else if(![this currentAsset]){
                                [this setStep:ScreenshotStepGetResource];
                            }
                            else if(![this path]){
                                [this setStep:ScreenshotStepGetUrl];
                            }
                            else {
                                [this setResult: [[NSDictionary alloc] initWithObjectsAndKeys :
                                                         [this path], @"filePath",
                                                         @"true", @"success",
                                                         nil]];
                                [this setStep:ScreenshotStepFinish];
                            }
                        }
                        else if([PHPhotoLibrary authorizationStatus] == AVAuthorizationStatusDenied)
                        {
                            [this setResult: [[NSDictionary alloc] initWithObjectsAndKeys :
                                              @"I need access to Photo Library...", @"filePath",
                                              @"true", @"success",
                                              nil]];
                            [this setStep:ScreenshotStepFinish];
                        }
                        else
                        {
                            if (firtTime){
                                [this setStep:ScreenshotStepMakeAlbum];
                                firtTime = NO;
                            }
                            else
                                [this setStep:ScreenshotStepWaiting];
                            
                        }
                        break;
                    }
                    case ScreenshotStepMakeAlbum:
                    {
                        NSLog(@"ScreenshotStepMakeAlbum...");
                        [this setStep: ScreenshotStepRendering];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self makeAlbumWithTitle:albumName onSuccess:^(PHAssetCollection *album) {
                                [this setCurrentAlbum: album];
                                [this setStep: ScreenshotStepTesting];
                            } onError:^(NSError *error) {
                                [this setStep: ScreenshotStepTesting];
                            }];
                        });
                        break;
                    }
                    case ScreenshotStepAddResource:
                    {
                        NSLog(@"ScreenshotStepAddResource...");
                        [this setStep: ScreenshotStepRendering];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self addNewAssetWithImage:image toAlbum:[this currentAlbum] onSuccess:^(NSString *ImageId) {
                                [this setIdentifierResource:ImageId];
                                [this setStep: ScreenshotStepTesting];
                            } onError:^(NSError *error) {
                                [this setStep: ScreenshotStepTesting];
                            }];
                        });
                        break;
                    }
                    case ScreenshotStepGetResource:
                    {
                        NSLog(@"ScreenshotStepGetResource...");
                        [this setStep: ScreenshotStepRendering];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [this setCurrentAsset: [self getAssetWithlocalIdentifier: [this identifierResource]]];
                            [this setStep: ScreenshotStepTesting];
                        });
                        break;
                    }
                    case ScreenshotStepGetUrl:
                    {
                        NSLog(@"ScreenshotStepGetUrl...");
                        [this setStep: ScreenshotStepRendering];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self getURLFromAssets: [this currentAsset] onSuccess:^(NSURL *url) {
                                [this setPath: [url absoluteString]];
                                [this setStep: ScreenshotStepTesting];
                            } onError:^(NSString *error) {
                                [this setStep: ScreenshotStepTesting];
                            }];
                            
                            [this setStep: ScreenshotStepTesting];
                        });
                        break;
                    }
                    case ScreenshotStepFinish:
                    {
                        NSLog(@"ScreenshotStepFinish...");
                        [this setStep: ScreenshotStepRendering];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: [this result]];
                            NSString* callbackId = command.callbackId;
                            [this.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                        });
                        
                        [this setRunning:NO];
                        break;
                    }
                    case ScreenshotStepRendering:
                    {
                        NSLog(@"ScreenshotStepRendering...");
                        [NSThread sleepForTimeInterval:0.1];
                        break;
                    }
                    case ScreenshotStepWaiting:
                    {
                        NSLog(@"ScreenshotStepWaiting...");
                        [NSThread sleepForTimeInterval:0.1];
                        [this setStep: ScreenshotStepTesting];
                        break;
                    }
                    default:
                    {
                        NSLog(@"This step no supported...");
                        break;
                    }
                }
            }
        });
    }

    - (void) getScreenshotAsURI:(CDVInvokedUrlCommand*)command
    {
        NSNumber *quality = command.arguments[0];
        UIImage *image = [self getScreenshot];
        NSData *imageData = UIImageJPEGRepresentation(image,[quality floatValue]);
        NSString *base64Encoded = [imageData base64EncodedStringWithOptions:0];
        NSDictionary *jsonObj = @{
                                  @"URI" : [NSString stringWithFormat:@"data:image/jpeg;base64,%@", base64Encoded]
                                  };
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsonObj];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:[command callbackId]];
    }
    
    
    
#pragma mark Primitive Photo Album
    
    -(void)makeAlbumWithTitle:(NSString *)title onSuccess:(void(^)(PHAssetCollection* album))onSuccess onError: (void(^)(NSError * error)) onError
    {
        //Check weather the album already exist or not
        if (![self getAlbumWithName:title]) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                // Request editing the album.
                PHAssetCollectionChangeRequest *createAlbumRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:title];
                
                // Get a placeholder for the new asset and add it to the album editing request.
                PHObjectPlaceholder * placeHolder = [createAlbumRequest placeholderForCreatedAssetCollection];
                if (placeHolder) {
                    onSuccess( [self getAlbumWithName: title] );
                }
                
            } completionHandler:^(BOOL success, NSError *error) {
                //NSLog(@"Finished adding asset. %@", (success ? @"Success" : error));
                if (error) {
                    onError(error);
                }
            }];
        }
        else
        onSuccess( [self getAlbumWithName: title] );
    }
    
    -(void)addNewAssetWithImage:(UIImage *)image toAlbum:(PHAssetCollection *)album onSuccess:(void(^)(NSString *ImageId))onSuccess onError: (void(^)(NSError * error)) onError
    {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            // Request creating an asset from the image.
            PHAssetChangeRequest *createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
            
            // Request editing the album.
            PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:album];
            
            // Get a placeholder for the new asset and add it to the album editing request.
            PHObjectPlaceholder * placeHolder = [createAssetRequest placeholderForCreatedAsset];
            [albumChangeRequest addAssets:@[ placeHolder ]];
            
            //NSLog(@"%@",placeHolder.localIdentifier);
            
            
            if (placeHolder) {
                onSuccess(placeHolder.localIdentifier);
            }
            
            
        } completionHandler:^(BOOL success, NSError *error) {
            //NSLog(@"Finished adding asset. %@", (success ? @"Success" : error));
            if (error) {
                onError(error);
            }
        }];
    }
    
    
    -(PHAssetCollection *)getAlbumWithName:(NSString*)AlbumName
    {
        #if 0
        NSString * identifier = [[NSUserDefaults standardUserDefaults]objectForKey:kAlbumIdentifier];
        if (!identifier) return nil;
        PHFetchResult *assetCollections = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[identifier]
                                                                                               options:nil];
        #else
        PHFetchResult *assetCollections = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                                                                   subtype:PHAssetCollectionSubtypeAlbumRegular
                                                                                   options:nil];
        #endif
        //NSLog(@"assetCollections.count = %lu", (unsigned long)assetCollections.count);
        if (assetCollections.count == 0) return nil;
        
        __block PHAssetCollection * myAlbum;
        [assetCollections enumerateObjectsUsingBlock:^(PHAssetCollection *album, NSUInteger idx, BOOL *stop) {
            //NSLog(@"album:%@", album);
            //NSLog(@"album.localizedTitle:%@", album.localizedTitle);
            if ([album.localizedTitle isEqualToString:AlbumName]) {
                myAlbum = album;
                *stop = YES;
            }
        }];
        
        if (!myAlbum) return nil;
        return myAlbum;
    }
    
    -(NSArray *)getAssets:(PHFetchResult *)fetch
    {
        __block NSMutableArray * assetArray = NSMutableArray.new;
        [fetch enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop) {
            //NSLog(@"asset:%@", asset);
            [assetArray addObject:asset];
        }];
        return assetArray;
    }
    
    -(PHAsset  * _Nullable )getAssetWithlocalIdentifier:(NSString*)imageId
    {
        PHFetchResult *assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[imageId] options:nil];
        //if (assets.count == 0)
        //    return nil;
        
        NSArray * assetArray = [self getAssets:assets];
        
        if ([assetArray count] > 0) {
            return (PHAsset*)[assetArray firstObject];
        }
        return nil;
    }
    
    - (void)getImageWithIdentifier:(NSString*)imageId onSuccess:(void(^)(UIImage *image))onSuccess onError: (void(^)(NSError * error)) onError
    {
        NSError *error = [[NSError alloc] init];
        PHFetchResult *assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[imageId] options:nil];
        if (assets.count == 0) onError(error);
        
        NSArray * assetArray = [self getAssets:assets];
        PHImageManager *manager = [PHImageManager defaultManager];
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        [manager requestImageForAsset:assetArray.firstObject targetSize:screenRect.size contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            onSuccess(result);
            
        }];
    }
    
    -(void) getURLFromAssets: (PHAsset*) assets onSuccess:(void(^)(NSURL *url))onSuccess onError: (void(^)(NSString * error)) onError
    {
        if ([assets mediaType] == PHAssetMediaTypeImage)
        {
            PHContentEditingInputRequestOptions* options = [[PHContentEditingInputRequestOptions alloc] init];
            [options setCanHandleAdjustmentData:^BOOL(PHAdjustmentData *adjustmentData) { return YES; }];
            
            [assets requestContentEditingInputWithOptions:options completionHandler:^(PHContentEditingInput * _Nullable contentEditingInput, NSDictionary * _Nonnull info) {
                if (contentEditingInput && [contentEditingInput fullSizeImageURL])
                {
                    onSuccess([contentEditingInput fullSizeImageURL]);
                }
                else
                {
                    onError(@"Assets has not url path.");
                }
            }];
            
        }
        else
        {
            onError(@"Assets type not supported.");
        }
    }
#pragma mark -
    
@end
