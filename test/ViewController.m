//
//  ViewController.m
//  test
//
//  Created by Dirk-Willem van Gulik on 25-08-14.
//  Copyright (c) 2014 Dirk-Willem van Gulik. All rights reserved.
//

#import "ViewController.h"
#import <CryptoTokenKit/CryptoTokenKit.h>

@interface NSData (fingerprint)
-(NSString *)fingerprint;
@end

@implementation NSData (fingerprint)
-(NSString *)fingerprint {
    NSMutableString * str = [NSMutableString string];
    for(int i = 0; i < [self length]; i++)
        [str appendFormat:@"%s%02x", i ? ":" : "", ((unsigned char *)[self bytes])[i]];
    [str appendFormat:@" (%lu bytes)", (unsigned long)[self  length]];
    return str;
}
@end


@interface ViewController ()
@property (nonatomic, retain) TKSmartCardSlotManager * mngr;
@property (nonatomic, retain) NSMutableArray * slots;
@property (nonatomic, retain) NSMutableArray * cards;
@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
                                    
    self.mngr = [TKSmartCardSlotManager defaultManager];
    assert(self.mngr);

    // Observe readers joining and leaving.
    //
    [self.mngr addObserver:self forKeyPath:@"slotNames" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionInitial context:nil];

}

-(void)dealloc {
    [self.mngr removeObserver:self forKeyPath:@"slotNames"];

    for(id slot in self.slots)
        [slot removeObserver:self];
    
    for(id card in self.cards)
        [card removeObserver:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    if ([keyPath isEqualToString:@"slotNames"]) {
        NSLog(@"(Re)Scanning Slots: %@",[self.mngr slotNames]);
        
        // Purge any old observing and rebuild the array.
        //
        for(id slot in _slots) {
            [slot removeObserver:self forKeyPath:@"state"];

        }
        for(id card in self.cards)
            [card removeObserver:self forKeyPath:@"valid"];
        
        self.slots = [[NSMutableArray alloc] init];
        self.cards = [[NSMutableArray alloc] init];

        for(NSString *slotName in [_mngr slotNames]) {

            [_mngr getSlotWithName:slotName reply:^(TKSmartCardSlot *slot) {
                [_slots addObject:slot];
                
                [slot addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionInitial context:nil];
                
                NSLog(@"Slot:    %@",slot);
                NSLog(@"  name:  %@",slot.name);
                NSLog(@"  state: %@",[self stateString:slot.state]);
            }];
        };
    }  // end of Slot change
    else if ([keyPath isEqualToString:@"state"]) {
        TKSmartCardSlot * slot = object;
        NSLog(@"  state: %@ for %@",[self stateString:slot.state], slot);
        
        if (slot.state == TKSmartCardSlotStateValidCard) {
            NSLog(@"  atr:   %@",slot.ATR);
            
            TKSmartCardATRInterfaceGroup * iface = [slot.ATR interfaceGroupForProtocol:TKSmartCardProtocolT1];
            NSLog(@"Iface for T1: %@", iface);
            
            TKSmartCard * sc = [slot makeSmartCard];
            [_cards addObject:sc];
            
            [sc addObserver:self forKeyPath:@"valid" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionInitial context:nil];
            
            NSLog(@"Card: %@", sc);
            NSLog(@"Allowed protocol bitmask: %lx", sc.allowedProtocols);
            
            if (sc.allowedProtocols & TKSmartCardProtocolT0)
                NSLog(@"        T0");
            if (sc.allowedProtocols & TKSmartCardProtocolT1)
                NSLog(@"        T1");
            if (sc.allowedProtocols & TKSmartCardProtocolT15)
                NSLog(@"        T15");
        }

    }
    else if ([keyPath isEqualToString:@"valid"]) {
        TKSmartCard * sc = object;
        
        if (sc.valid) [sc beginSessionWithReply:^(BOOL success, NSError *error) {
            NSLog(@"Card in slot <%@>",sc.slot.name);
            NSLog(@"   now in session, selected protocol: %lx", sc.currentProtocol);
            
            assert(sc.currentProtocol != TKSmartCardProtocolNone);
            
#if 0
            static const char pin[] = { '1', '2','3','4',0xFF,0xFF,0xFF,0xFF };
            [sc sendIns:0x20
                     p1:0
                     p2:0
                   data:[NSData dataWithBytes:pin length:sizeof(pin)]
                     le:0
                  reply:^(NSData *replyData, UInt16 sw, NSError *error) {
                      NSLog(@"Error: %@", error);
                      NSLog(@"Data:  %@", replyData);
                      NSLog(@"SW:    %02x/%02x", sw >> 8, sw & 0xFF);
                  }
             ];
#endif
#if 0
            sc.cla = 0x0;
            [sc sendIns:0x84 // entersafe - get me a random number
                     p1:0
                     p2:0
                   data:nil
                     le:[NSNumber numberWithInt:8]
                  reply:^(NSData *replyData, UInt16 sw, NSError *error) {
                      assert(!error);
                      NSLog(@"SW:    %02x/%02x", sw >> 8, sw & 0xFF);
                      NSLog(@"random data:  %@", [replyData fingerprint]);
                  }
             ];
#endif
#if 1
            sc.cla = 0x80;
            [sc sendIns:0xEA // entersafe - get card serial number
                     p1:0
                     p2:0
                   data:nil
                     le:[NSNumber numberWithInt:8] // what we expect *back*
                  reply:^(NSData *replyData, UInt16 sw, NSError *error) {
                      assert(!error);
                      NSLog(@"SW:      %02x/%02x", sw >> 8, sw & 0xFF);
                      NSLog(@"Serial:  %@", [replyData fingerprint]);
                  }
             ];
#endif
            
            [sc endSession];
        }];
    } // end of TKSmartCard sc valid change
    else {
        NSLog(@"Ignored...");
    }
} // end of function

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
    
}

-(NSString *)stateString:(TKSmartCardSlotState)state {
    switch (state) {
        case TKSmartCardSlotStateEmpty:
            return @"TKSmartCardSlotStateEmpty";
            break;
        case TKSmartCardSlotStateMissing:
            return @"TKSmartCardSlotStateMissing";
            break;
        case TKSmartCardSlotStateMuteCard:
            return @"TKSmartCardSlotStateMuteCard";
            break;
        case TKSmartCardSlotStateProbing:
            return @"TKSmartCardSlotStateProbing";
            break;
        case TKSmartCardSlotStateValidCard:
            return @"TKSmartCardSlotStateValidCard";
            break;
        default:
            return @"error";
            break;
    }
    return @"bug";
}
@end
