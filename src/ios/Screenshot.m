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
    ScreenshotSaveStepMakeAlbum,
    ScreenshotSaveStepAddResource,
    ScreenshotSaveStepGetResource,
    ScreenshotSaveStepGetUrl,
    ScreenshotSaveStepRendering,
    ScreenshotSaveStepWaiting,
    ScreenshotSaveStepTesting,
    ScreenshotSaveStepFinish
} ScreenshotSaveSteps;

typedef enum
{
    ScreenshotGet64StepFindAlbum,
    ScreenshotGet64StepGetResource,
    ScreenshotGet64StepGetUrl,
    ScreenshotGet64StepRendering,
    ScreenshotGet64StepWaiting,
    ScreenshotGet64StepTesting,
    ScreenshotGet64StepFinish
} ScreenshotGet64Steps;

@property BOOL isMakingAlbum;

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
    
    NSNumber *quality = command.arguments[0];
    UIImage *tempImage = [self getScreenshot];
    NSData *imageData = UIImageJPEGRepresentation(tempImage, [quality floatValue]);
    
    UIImage* image = [UIImage imageWithData:imageData];

    [self setIsMakingAlbum:NO];
    
    __block Screenshot* this = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        __block ScreenshotSaveSteps step = ScreenshotSaveStepTesting;
        __block PHAssetCollection *currentAlbum;
        __block NSString *identifierResource;
        __block PHAsset *currentAsset;
        __block NSString *path;
        __block BOOL running;
        __block NSDictionary *result;
        
        running = YES;
        
        BOOL firtTime = YES;
        while (running)
        {
            switch (step) {
                case ScreenshotSaveStepTesting:
                {
                    //NSLog(@"ScreenshotSaveStepTesting...");
                    if([PHPhotoLibrary authorizationStatus] == AVAuthorizationStatusAuthorized)
                    {
                        if (!currentAlbum)
                        {
                            step = ScreenshotSaveStepMakeAlbum;
                        }
                        else if(!identifierResource)
                        {
                            step = ScreenshotSaveStepAddResource;
                        }
                        else if(!currentAsset){
                            step = ScreenshotSaveStepGetResource;
                        }
                        else if(!path){
                            step = ScreenshotSaveStepGetUrl;
                        }
                        else {
                            result = @{
                                       @"filePath" : path,
                                       @"success" : @"true"
                                       };
                            step = ScreenshotSaveStepFinish;
                        }
                    }
                    else if([PHPhotoLibrary authorizationStatus] == AVAuthorizationStatusDenied)
                    {
                        result = @{
                                   @"message" : @"I need access to Photo Library...",
                                   @"success" : @"false"
                                   };
                        step = ScreenshotSaveStepFinish;
                    }
                    else
                    {
                        if (firtTime){
                            step = ScreenshotSaveStepMakeAlbum;
                            firtTime = NO;
                        }
                        else
                            step = ScreenshotSaveStepWaiting;
                        
                    }
                    break;
                }
                case ScreenshotSaveStepMakeAlbum:
                {
                    //NSLog(@"ScreenshotSaveStepMakeAlbum...");
                    step = ScreenshotSaveStepRendering;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self makeAlbumWithTitle:albumName onSuccess:^(PHAssetCollection *album) {
                            currentAlbum = album;
                            step = ScreenshotSaveStepTesting;
                        } onError:^(NSError *error) {
                            step = ScreenshotSaveStepTesting;
                        }];
                    });
                    break;
                }
                case ScreenshotSaveStepAddResource:
                {
                    //NSLog(@"ScreenshotSaveStepAddResource...");
                    step = ScreenshotSaveStepRendering;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self addNewAssetWithImage:image toAlbum:currentAlbum onSuccess:^(NSString *ImageId) {
                            identifierResource = ImageId;
                            step = ScreenshotSaveStepTesting;
                        } onError:^(NSError *error) {
                            step = ScreenshotSaveStepTesting;
                        }];
                    });
                    break;
                }
                case ScreenshotSaveStepGetResource:
                {
                    //NSLog(@"ScreenshotSaveStepGetResource...");
                    step = ScreenshotSaveStepRendering;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        currentAsset = [self getAssetWithLocalIdentifier: identifierResource];
                        step = ScreenshotSaveStepTesting;
                    });
                    break;
                }
                case ScreenshotSaveStepGetUrl:
                {
                    //NSLog(@"ScreenshotSaveStepGetUrl...");
                    step = ScreenshotSaveStepRendering;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self getURLFromAssets: currentAsset onSuccess:^(NSURL *url) {
                            path = [url absoluteString];
                            step = ScreenshotSaveStepTesting;
                        } onError:^(NSString *error) {
                            step = ScreenshotSaveStepTesting;
                        }];
                        
                        step = ScreenshotSaveStepTesting;
                    });
                    break;
                }
                case ScreenshotSaveStepFinish:
                {
                    //NSLog(@"ScreenshotSaveStepFinish...");
                    step = ScreenshotSaveStepRendering;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: result];
                        NSString* callbackId = command.callbackId;
                        [this.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                    });
                    
                    running =NO;
                    break;
                }
                case ScreenshotSaveStepRendering:
                {
                    //NSLog(@"ScreenshotSaveStepRendering...");
                    [NSThread sleepForTimeInterval:0.1];
                    break;
                }
                case ScreenshotSaveStepWaiting:
                {
                    //NSLog(@"ScreenshotSaveStepWaiting...");
                    [NSThread sleepForTimeInterval:0.1];
                    step = ScreenshotSaveStepTesting;
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

- (void) getResourceAsURI:(CDVInvokedUrlCommand*)command
{
    NSNumber *quality = command.arguments[0];
    NSString *albumName = command.arguments[1];
    NSString *fileName = command.arguments[2];
    
    __block Screenshot* this = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        __block ScreenshotGet64Steps step = ScreenshotGet64StepTesting;
        __block PHAssetCollection *currentAlbum;
        __block PHAsset *currentAsset;
        __block NSString *image64;
        __block BOOL running;
        __block BOOL cropResult = NO;
        __block NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
        __block NSString *errorMessage;
        
        running = YES;
        
        BOOL firtTime = YES;
        while (running)
        {
            switch (step) {
                case ScreenshotGet64StepTesting:
                {
                    //NSLog(@"ScreenshotGet64Step : Testing...");
                    if([PHPhotoLibrary authorizationStatus] == AVAuthorizationStatusAuthorized)
                    {
                        if (!errorMessage)
                        {
                            if (!currentAlbum)
                            {
                                step = ScreenshotGet64StepFindAlbum;
                            }
                            else if(!currentAsset){
                                step = ScreenshotGet64StepGetResource;
                            }
                            else if(!image64){
                                step = ScreenshotGet64StepGetUrl;
                            }
                            else {
                                cropResult = YES;
                                [result setValue:@"true" forKey:@"success"];
                                step = ScreenshotGet64StepFinish;
                            }
                        }
                        else
                        {
                            [result setValue:@"false" forKey:@"success"];
                            [result setValue:errorMessage forKey:@"message"];
                            step = ScreenshotGet64StepFinish;
                        }
                    }
                    else if([PHPhotoLibrary authorizationStatus] == AVAuthorizationStatusDenied)
                    {
                        [result setValue:@"false" forKey:@"success"];
                        [result setValue:@"I need access to Photo Library..." forKey:@"message"];
                        step = ScreenshotGet64StepFinish;
                    }
                    else
                    {
                        if (firtTime){
                            step = ScreenshotGet64StepFindAlbum;
                            firtTime = NO;
                        }
                        else
                            step = ScreenshotGet64StepWaiting;
                        
                    }
                    break;
                }
                case ScreenshotGet64StepFindAlbum:
                {
                    //NSLog(@"ScreenshotGet64Step : FindAlbum...");
                    step = ScreenshotGet64StepRendering;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        currentAlbum = [self getAlbumWithName: albumName];
                        step = ScreenshotGet64StepWaiting;
                    });
                    break;
                }
                case ScreenshotGet64StepGetResource:
                {
                    //NSLog(@"ScreenshotGet64Step : GetResource...");
                    step = ScreenshotGet64StepRendering;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self getAssetImageWithName:fileName fromAlbum:currentAlbum onSuccess:^(PHAsset *image) {
                            currentAsset = image;
                            step = ScreenshotGet64StepTesting;
                        } onError:^(NSString *message) {
                            step = ScreenshotGet64StepTesting;
                        }];
                        
                    });
                    break;
                }
                case ScreenshotGet64StepGetUrl:
                {
                    //NSLog(@"ScreenshotGet64Step : GetUrl...");
                    step = ScreenshotGet64StepRendering;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        [self getImageBase64FromAsset:currentAsset quality:quality onSuccess:^(NSString *imageBase64) {
                            image64 = imageBase64;
                            step = ScreenshotGet64StepTesting;
                        } onError:^(NSString *message) {
                            step = ScreenshotGet64StepTesting;
                        }];
                    });
                    break;
                }
                case ScreenshotGet64StepFinish:
                {
                    //NSLog(@"ScreenshotGet64Step : Finish...");
                    step = ScreenshotGet64StepRendering;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        unsigned long pivot = 0;
                        long lenght = 32000;
                        double percent = 0;
                        BOOL completed = NO;
                        NSString* data = @"";
                        if (cropResult)
                        {
                            while (!completed)
                            {
                                if (pivot+lenght> [image64 length])
                                    data = [image64 substringFromIndex:pivot];
                                else
                                    data = [image64 substringWithRange:NSMakeRange(pivot, lenght)];
                                pivot += [data length];
                                percent = (pivot / (double)[image64 length])*100;
                                completed = pivot == [image64 length];
                                //NSLog(@"Sended: %.02f", percent);
                                [result setValue:data forKey:@"data"];
                                [result setValue:[NSString stringWithFormat:@"%.02f", percent] forKey:@"percent"];
                                [result setValue:fileName forKey:@"name"];
                                [result setValue:completed ? @"true" : @"false" forKey:@"completed"];
                                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
                                
                                [pluginResult setKeepCallbackAsBool: true];
                                NSString* callbackId = command.callbackId;
                                [this.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                            }
                        }
                        else
                        {
                            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: result];
                            NSString* callbackId = command.callbackId;
                            [pluginResult setKeepCallbackAsBool: true];
                            [this.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                        }
                    });
                    running =NO;
                    break;
                }
                case ScreenshotGet64StepRendering:
                {
                    //NSLog(@"ScreenshotGet64Step : Rendering...");
                    [NSThread sleepForTimeInterval:0.1];
                    break;
                }
                case ScreenshotGet64StepWaiting:
                {
                    //NSLog(@"ScreenshotGet64Step : Waiting...");
                    [NSThread sleepForTimeInterval:0.1];
                    step = ScreenshotGet64StepTesting;
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

#pragma mark Primitive Photo Album

-(void)getImageBase64FromAsset:(PHAsset *)image quality:(NSNumber*)quality onSuccess:(void(^)(NSString* imageBase64))onSuccess onError: (void(^)(NSString *message)) onError
{
    PHImageRequestOptions * requestOptions = [[PHImageRequestOptions alloc] init];
    
    PHImageManager *manager = [PHImageManager defaultManager];
    [manager requestImageForAsset:image
                       targetSize:PHImageManagerMaximumSize//CGSizeMake(300, 300)
                      contentMode:PHImageContentModeDefault
                          options:requestOptions
                    resultHandler:^void(UIImage *image, NSDictionary *info)
     {
         NSData *imageData = UIImageJPEGRepresentation(image, [quality floatValue]);
         NSString *base64Encoded = [imageData base64EncodedStringWithOptions:0];
         onSuccess([NSString stringWithFormat:@"data:image/jpeg;base64,%@", base64Encoded]);
     }];
}

-(void)getAssetImageWithName:(NSString *)name fromAlbum:(PHAssetCollection*)album onSuccess:(void(^)(PHAsset* image))onSuccess onError: (void(^)(NSString *message)) onError
{
    PHFetchResult *collectionResult = [PHAsset fetchAssetsInAssetCollection:album options:nil];
    
    [collectionResult enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop)
     {
         NSArray *resources = [PHAssetResource assetResourcesForAsset:asset];
         NSString *orgFilename = ((PHAssetResource*)resources[0]).originalFilename;
         
         if ([[orgFilename lowercaseString] isEqualToString: [name lowercaseString]])
         {
             onSuccess(asset);
             *stop = YES;
         }
     }];
}

-(void)makeAlbumWithTitle:(NSString *)title onSuccess:(void(^)(PHAssetCollection* album))onSuccess onError: (void(^)(NSError * error)) onError
{
    //Check weather the album already exist or not
    if (![self getAlbumWithName:title]) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            // Request editing the album.
            if (![self isMakingAlbum])
            {
                [self setIsMakingAlbum:YES];
                PHAssetCollectionChangeRequest *createAlbumRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:title];
                
                // Get a placeholder for the new asset and add it to the album editing request.
                PHObjectPlaceholder * placeHolder = [createAlbumRequest placeholderForCreatedAssetCollection];
                if (placeHolder) {
                    onSuccess( [self getAlbumWithName: title] );
                }
                [self setIsMakingAlbum:NO];
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

-(PHAsset  * _Nullable )getAssetWithLocalIdentifier:(NSString*)imageId
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
