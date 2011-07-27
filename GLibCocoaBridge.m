//
//  GLibCocoaBridge.m
//  MultiMarkdown
//
//  Created by Daniel Jalkut on 7/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GLibCocoaBridge.h"

// GString

void recacheUTF8String(GString* theGString)
{
	// We always keep a complete copy ... potentially expensive, yes, but it
	// is necessary in case the client has grabbed theGString->str just before
	// freeing us without freeing the str representation.
	if (theGString->str != NULL)
	{
		free(theGString->str);
	}
	char* utf8String = (char*) [theGString->cocoaString UTF8String];
	NSUInteger stringLength = strlen(utf8String);
	theGString->str = malloc(stringLength + 1);
	strncpy(theGString->str, utf8String, stringLength+1);
}

GString* g_string_new(char *startingString)
{
	GString* newString = malloc(sizeof(GString));

	if (startingString == NULL) startingString = "";

	newString->cocoaString = [[NSMutableString stringWithUTF8String:startingString] retain];
	newString->str = NULL;

	// Clear the UTF fragments
	newString->utf8Fragments[0] = '\0';
	
	recacheUTF8String(newString);
	
	return newString;
}

char* g_string_free(GString* ripString, bool freeCharacterData)
{	
	char* returnedString = ripString->str;
	if (freeCharacterData)
	{
		if (ripString->str != NULL)
		{
			free(ripString->str);
		}
		returnedString = NULL;
	}
	
	[ripString->cocoaString release];
	free(ripString);
	
	return returnedString;
}

void g_string_append_c(GString* baseString, char appendedCharacter)
{	
	int thisUTFIndex = 0;
	while (baseString->utf8Fragments[thisUTFIndex] != '\0')
	{
		thisUTFIndex++;
	}
	
	if (thisUTFIndex > 3)
	{
		NSLog(@"Got too many contiguous non-parseable characters. Starting over!");
		baseString->utf8Fragments[0] = '\0';
		thisUTFIndex = 0;
	}
	
	baseString->utf8Fragments[thisUTFIndex] = appendedCharacter;
	baseString->utf8Fragments[thisUTFIndex+1] = '\0';
	
	NSString* newString = [NSString stringWithUTF8String:baseString->utf8Fragments];
	if (newString != nil)
	{
		[baseString->cocoaString appendString:newString];	
		recacheUTF8String(baseString);
		
		// Clear the UTF fragments
		baseString->utf8Fragments[0] = '\0';
	}
}

void g_string_append(GString* baseString, char* appendedString)
{
	if ((appendedString != NULL) && (strlen(appendedString) > 0))
	{
		[baseString->cocoaString appendString:[NSString stringWithUTF8String:appendedString]];
		recacheUTF8String(baseString);
	}
}

void g_string_append_printf(GString* baseString, char* format, ...)
{
	va_list args;
	va_start(args, format);
	
	// Thanks to Mike Ash for the tip about using initWithFormat:arguments: to work around warnings
	// when the caller doesn't provide any varargs.
	NSString* appendedString = [[NSString alloc] initWithFormat:[NSString stringWithUTF8String:format] arguments:args];
	g_string_append(baseString, (char*)[appendedString UTF8String]);
} 

void g_string_prepend(GString* baseString, char* prependedString)
{
	[baseString->cocoaString insertString:[NSString stringWithUTF8String:prependedString] atIndex:0];
	recacheUTF8String(baseString);
}

// GSList

void g_slist_free(GSList* ripList)
{
	GSList* thisListItem = ripList;
	while (thisListItem != NULL)
	{
		GSList* nextItem = thisListItem->next;
		
		// I guess we don't release the data? Non-retained memory management is hard... let's figure it out later.
		free(thisListItem);
		
		thisListItem = nextItem;
	}
}

// Currently only used for markdown_output.c endnotes printing
GSList* g_slist_reverse(GSList* theList)
{	
	GSList* lastNodeSeen = NULL;
	
	// Iterate the list items, tacking them on to our new reversed List as we find them
	GSList* listWalker = theList;
	while (listWalker != NULL)
	{
		GSList* nextNode = listWalker->next;
		listWalker->next = lastNodeSeen;
		lastNodeSeen = listWalker;
		listWalker = nextNode;
	}
	
	return lastNodeSeen;
}

GSList* g_slist_prepend(GSList* targetElement, void* newElementData)
{
	GSList* newElement = malloc(sizeof(GSList));
	newElement->data = newElementData;
	newElement->next = targetElement;
	return newElement;
}

