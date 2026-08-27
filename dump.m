#import <Foundation/Foundation.h>
#import <objc/runtime.h>

int main() {
    dlopen("/System/Library/CoreServices/SpringBoard.app/SpringBoard", RTLD_LAZY);
    unsigned int count = 0;
    Method *methods = class_copyMethodList(NSClassFromString(@"SBIconController"), &count);
    for (unsigned int i = 0; i < count; i++) {
        NSString *name = NSStringFromSelector(method_getName(methods[i]));
        if ([name containsString:@"Edit"] || [name containsString:@"edit"]) {
            printf("- %s\n", name.UTF8String);
        }
    }
    return 0;
}
