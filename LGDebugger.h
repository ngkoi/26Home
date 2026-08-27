#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#ifdef __cplusplus
extern "C" {
#endif

// Log routing logic to /var/tmp/26home_dump.txt
static inline void Home26LogToFile(NSString *msg) {
    NSString *logPath = @"/var/tmp/26home_dump.txt"; 
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (!fileHandle) {
        // Create the file if it doesn't exist
        [msg writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[[msg stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    }
}

static inline void Home26Log(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSLog(@"[26Home] %@", msg);
    
    NSString *fileMsg = [NSString stringWithFormat:@"[%@] %@", [NSDate date], msg];
    Home26LogToFile(fileMsg);
}

static inline void Home26DumpClass(Class cls) {
    if (!cls) {
        Home26Log(@"[DUMP ERROR] Attempted to dump nil class.");
        return;
    }
    
    NSMutableString *dump = [NSMutableString stringWithFormat:@"\n\n=================================\n"];
    [dump appendFormat:@"CLASS DUMP: %@\n", NSStringFromClass(cls)];
    [dump appendString:@"=================================\n"];
    
    unsigned int count = 0;
    
    // Properties
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    [dump appendFormat:@"\n--- Properties (%u) ---\n", count];
    for (unsigned int i = 0; i < count; i++) {
        [dump appendFormat:@"@property %s %s;\n", property_getName(properties[i]), property_getAttributes(properties[i])];
    }
    free(properties);
    
    // Ivars
    Ivar *ivars = class_copyIvarList(cls, &count);
    [dump appendFormat:@"\n--- Ivars (%u) ---\n", count];
    for (unsigned int i = 0; i < count; i++) {
        [dump appendFormat:@"%s %s;\n", ivar_getName(ivars[i]), ivar_getTypeEncoding(ivars[i])];
    }
    free(ivars);
    
    // Methods
    Method *methods = class_copyMethodList(cls, &count);
    [dump appendFormat:@"\n--- Instance Methods (%u) ---\n", count];
    for (unsigned int i = 0; i < count; i++) {
        [dump appendFormat:@"- %s;\n", sel_getName(method_getName(methods[i]))];
    }
    free(methods);
    
    // Class Methods
    Method *classMethods = class_copyMethodList(object_getClass((id)cls), &count);
    [dump appendFormat:@"\n--- Class Methods (%u) ---\n", count];
    for (unsigned int i = 0; i < count; i++) {
        [dump appendFormat:@"+ %s;\n", sel_getName(method_getName(classMethods[i]))];
    }
    free(classMethods);
    
    [dump appendString:@"\n=================================\n"];
    
    Home26Log(@"%@", dump); // Will also log to file
}

// Runtime View Hierarchy Dumper
static inline void Home26DumpViewHierarchy(UIView *view) {
    if (!view) {
        Home26Log(@"[DUMP ERROR] Attempted to dump nil view.");
        return;
    }
    
    Home26Log(@"\n\n=== VIEW HIERARCHY DUMP ===\n%@\n===========================", [view performSelector:@selector(recursiveDescription)]);
}

#import <mach-o/dyld.h>
#import <sys/utsname.h>

// Diagnostics and Conflict Reporter
static inline void Home26GenerateDiagnosticsReport(void) {
    NSMutableString *report = [NSMutableString stringWithString:@"\n\n=== 26Home Diagnostics ===\n"];
    
    struct utsname systemInfo;
    uname(&systemInfo);
    [report appendFormat:@"Device Model: %s\n", systemInfo.machine];
    [report appendFormat:@"iOS Version: %@\n", [[UIDevice currentDevice] systemVersion]];
    
    [report appendString:@"\n--- Current Tweak Preferences ---\n"];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    [report appendFormat:@"%@\n", [[defaults dictionaryRepresentation] description]];
    
    [report appendString:@"\n--- Loaded Tweak Dylibs ---\n"];
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *imageName = _dyld_get_image_name(i);
        if (imageName) {
            NSString *name = [NSString stringWithUTF8String:imageName];
            // Filter for jailbreak tweaks specifically
            if ([name containsString:@"/Library/MobileSubstrate/DynamicLibraries"] || 
                [name containsString:@"/var/jb/"] || 
                [name containsString:@"/TweakInject/"]) {
                [report appendFormat:@"- %@\n", [name lastPathComponent]];
            }
        }
    }
    
    [report appendString:@"=================================\n"];
    
    // Save to a separate diagnostics file
    NSString *diagPath = @"/var/tmp/26home_diagnostics.txt";
    [report writeToFile:diagPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    Home26Log(@"[Diagnostics] Successfully saved report to %@", diagPath);
}

#ifdef __cplusplus
}
#endif
