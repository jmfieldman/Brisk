![Brisk](/Assets/Banner.png)

Swift support for blocks and asynchronous code is powerful, but can lead to a maze of indented logic that
quickly becomes unreadable and error-prone.

Brisk offers two distinct but complimentary functions:

1. Extends the standard GCD library with several functions that help make standard usage a bit more concise.
2. Provides shorthand operators for swiveling the concurrency of your functions.

These might be best explained by code example.

### Quick Look: Extending the GCD Library for Simplicity ###

Consider the existing methods required from the standard GCD library:

```swift
// Dispatch a block to the main queue
dispatch_async(dispatch_get_main_queue()) {
    // ...
}

// Dispatch a block to the main queue after 2.0 seconds
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2.0 * Double(NSEC_PER_SEC))),
               dispatch_get_main_queue()) {
    // ...
}
```

Compared to their Brisk equivalents:

```swift
// Dispatch a block to the main queue
dispatch_main_async {
    // ...
}

// Dispatch a block to the main queue after 2.0 seconds
dispatch_main_after(2.0) {
    // ...
}
```

Brisk offers this type of simplification for many standard GCD use cases.

### Quick Look: Concurrency Swiveling ###

Consider the following hypothetical asynchronous API (using Swift 2.2 function syntax):

```swift
// API we're given:
func findClosestPokemonWithin(within: Double,
                   completionHandler: (pokemon: Pokemon?, error: NSError?) -> Void)

func countPokeballs(completionHandler: (number: Int?, error: NSError?) -> Void)

func throwPokeballAtPokemon(pokemon: Pokemon,
                  completionHandler: (success: Bool, error: NSError?) -> Void)
```

Let's assume that all of the completion handlers are called on the main thread.  We want to
make this utility function:

```swift
// Utility we want:
func throwAtClosestPokemonWithin(within: Double,
                      completionHandler: (success: Bool, pokemon: Pokemon?, error: NSError?) -> Void)
```

This function represents a common occurrence of chaining asynchronous functions into a helper utility for a single use case.
Using only the standard GCD library, your function might look like this:

```swift
// The old way...
func throwAtClosestPokemonWithin(within: Double,
                      completionHandler: (success: Bool, pokemon: Pokemon?, error: NSError?) -> Void) {
    // Step 1
    findClosestPokemonWithin(within) { pokemon, error in
        guard let p = pokemon where error == nil else {
            dispatch_main_async {
                completionHandler(success: false, pokemon: nil, error: error)
            }
            return
        }

        // Step 2
        countPokeballs { number, error in
            guard let n = number where error == nil else {
                dispatch_main_async {
                    completionHandler(success: false, pokemon: nil, error: error)
                }
                return
            }

            // Step 3
            throwPokeballAtPokemon(p) { success, error in
                dispatch_main_async {
                    completionHandler(success: success, error: error)
                }
            }
        }
    }
}
```

With Brisk:

```swift
// The new way...
func throwAtClosestPokemonWithin(within: Double,
                      completionHandler: (success: Bool, pokemon: Pokemon?, error: NSError?) -> Void) {
    dispatch_bg_async {

        // Step 1
        let (pokemon, error) = <<+{ findClosestPokemonWithin(within, completionHandler: $0) }
        guard let p = pokemon where error == nil else {
            return completionHandler +>> (success: false, error: error)
        }

        // Step 2
        let (number, error2) = <<+{ countPokeballs($0) }
        guard let n = number where error2 == nil else {
            return completionHandler +>> (success: false, error: error2)
        }

        // Step 3
        let (success, error3) = <<+{ throwPokeballAtPokemon(p, completionHandler: $0) }
        completionHandler +>> (success: success, error: error3)
    }
}
```

The main advantage with Brisk is that the asynchronous functions can be coded using a seemingly-synchronous flow.
The asynchronous nature of the methods is hidden behind the custom operators.  *Unlike PromiseKit, all return values
remain in scope as well*.

## Detailed GCD Additions ##

The following code examples show the GCD additions provided by Brisk.  These are
fairly self-documenting.  More information about each method can be found in its comment section.

```swift
dispatch_main_async {
    // Block runs on the main queue
}

dispatch_main_sync {
    // Block runs on the main queue; this function does not return until
    // the block completes.
}

dispatch_bg_async {
    // Block runs on the global concurrent background queue
}

dispatch_async("myNewQueue") {
    // Block runs on a brisk-created serial queue with the specified string ID.
    // Calling this function multiple times with the same string will reuse the
    // named queue.  Useful for dynamic throw-away serial queues.
}

dispatch_main_after(2.0) {
dispatch_after(2.0, myQueue) {
    // Block is called on specified queue after specified number of seconds using
    // a loose leeway (+/- 0.1 seconds).
}

dispatch_main_after_exactly(2.0) {
dispatch_after_exactly(2.0, myQueue) {
    // Block is called on specified queue after specified number of seconds using
    // as tight a timer leeway as possible.  Useful for animation timing but
    // uses more battery power.
}

dispatch_main_every(2.0) { timer in
dispatch_every(2.0, myQueue) { timer in
dispatch_main_every_exact(2.0) { timer in
dispatch_every_exact(2.0, myQueue) { timer in
    // Block is run on specified thread every N seconds.
    // Stop the timer with:
    dispatch_source_cancel(timer)
}

dispatch_main_once_after(2.0, "myOperationId") {
dispatch_once_after(2.0, myQueue, "myOperationId") {
    // Block runs after specified time on specified queue.  The block is
    // only executed ONCE -- repeat calls to this function with the same
    // operation ID will reset its internal timer instead of calling the
    // block again.  Useful for calling a completion block after several
    // disparate asynchronous methods (e.g. saving the database to disk
    // after downloading multiple records on separate threads.)
}

dispatch_each(myArray, myQueue) { element in
    // Each element in the array has this block called with it as a parameter.
    // Should be used on a concurrent queue.
}
```

## Calling Asynchronous Functions Synchronously ##

This section refers the idea of taking a naturally asynchronous function and calling
it synchronously, generally for the purpose of chaining multiple asynchronous
operations.  This is essentially the same offering of PromiseKit but without
the needless indentation and scope shuffle that comes with it.

To see a practical use case, refer to the Quick Look example at the beginning of
this document.

When we talk about an asynchronous function, it must abide by these characteristics:

* Returns ```Void```
* Takes any number of input parameters
* Has a single "completion" parameter that takes a function of the form ```(...) -> Void```

These are all examples of suitable asynchronous functions:

```swift
func getAlbum(named: String, handler: (album: PhotoAlbum?, error: NSError?) -> Void)
func saveUser(completionHandler: (success: Bool) -> Void)
func verifyUser(name: String, password: String, completion: (valid: Bool) -> Void)

// Typical use of a function would look like:
getAlbum("pics") { photo, error in
    // ...
}
```

With Brisk, you can use the ```<<+```, ```<<~``` or ```<<-``` operators to call your function in
a way that blocks the calling thread until your function has called its completion
handler.

```swift
// <<+ will execute getAlbum on the main queue
let (album, error) = <<+{ getAlbum("pics", handler: $0) }

// <<~ will execute saveUser on the global concurrent background queue
let success        = <<~{ saveUser($0) }

// <<- will execute verifyUser immediately in the current queue (note that the
//     current thread will wait for the completion handler to be called before
//     returning the final value.)
let valid          = <<-{ verifyUser("myname", password: "mypass", completion: $0) }

// You can also specify *any* queue you want.  Here saveUser is called on myQueue.
let myQueue        = dispatch_queue_create("myQueue", nil)
let valid          = <<~myQueue ~~~ { saveUser($0) }
```

In all of the above examples, execution of the outer thread is paused until the completion
handler ```$0``` is called.  Once ```$0``` is called, the values passed into it are routed back
to the original assignment operation.

Note that the ```$0``` handler can accommodate any number of parameters (e.g. ```getAlbum```
above can take ```album``` and ```error```), but it must be assigned to variables that
create the same tuple.  Also note that it is not possible to extract ```NSError``` parameters
to transform them into do/try/catch methodology -- you will have to check the ```NSError```
as part of the returned tuple.

Also note that the outer thread WILL PAUSE until ```$0``` is called.  This means that
Brisk can only be used for functions that guarantee their completion handlers will
be called at some deterministic point in the future.  It is not suitable for open-ended
asynchronous functions like ```NSNotification``` handlers.

Another really important note: because of the requirement that ```$0``` is called, you should
never use this pattern with optional functions unless you can guarantee they are not nil!

```swift
func testFunction(handler: (Int -> Void)? = nil) {
    // This call will block forever if handler is nil!
    let z: Int = <<~{ handler?($0) }
}
```

## Calling Synchronous Functions Asynchronously ##

There are many reasons to call synchronous functions asynchronously.  It's happening any
time you see this pattern:

```swift
dispatch_async(someQueue) {
    // Do something
}
```

The stylistic problem with the pattern above is when ```"// Do something"``` is a single function.
You're burning three lines and an indentation scope just to route a single function call to
another queue.

An example of this is in the Quick Look example from the beginning of the documentation.  This
routing must take place each time the completion handler is called on the main queue.  It
has a negative impact on the readability of the overall function, since the actual function
name gets buried in the scope of the dispatch.  Wouldn't it be nice if that could be
accomplished in one line, with the function name first?

The ```~>>``` and ```+>>``` operators introduced in Brisk can be thought of as the
synchronous->asynchronous translators.  The main difference between the two is that
the ```+>>``` operator dispatches to the main queue, while the ```~>>``` operator
allows you to specify the queue (or use the concurrent background queue by default).

For the examples below, consider the following normal synchronous functions:

```swift
func syncReturnsVoid() { }
func syncReturnsParam(p: Int) -> Int { return p+1 }
func syncReturnsParamTuple(p: Int) -> (Int, String) { return (p+1, "\(p+1)") }
```

Use the infix operator between a function and its parameters to quickly dispatch a synchronous function on
another queue.

```swift
dispatch_async(someQueue) {

    // syncReturnsVoid() is called on the main thread
    syncReturnsVoid +>> ()

    // syncReturnsParam(p: 3) is called on the main thread
    // Note in this case the return value is ignored!
    syncReturnsParam +>> (p: 3)

    // syncReturnsVoid() is called on the global concurrent background queue
    syncReturnsVoid ~>> ()

    // syncReturnsParam(p: 3) is called on the global concurrent background queue
    // Note in this case the return value is ignored!
    syncReturnsParam ~>> (p: 3)

    let otherQueue = dispatch_queue_create("otherQueue", nil)

    // syncReturnsVoid() is called on otherQueue
    syncReturnsVoid ~>> otherQueue ~>> ()

    // syncReturnsParam(p: 3) is called on otherQueue
    // Note in this case the return value is ignored!
    syncReturnsParam ~>> otherQueue ~>> (p: 3)
}
```

You can also use the operators in a postfix fashion for a more functional syntax:

```swift
dispatch_async(someQueue) {    
    let otherQueue = dispatch_queue_create("otherQueue", nil)

    // The following three lines are equivalent
    syncReturnsParam~>>.on(otherQueue).async(p: 3)
    syncReturnsParam~>>otherQueue~>>(p: 3)
    syncReturnsParam ~>> otherQueue ~>> (p: 3)
}
```

In all of the above examples, the return values were ignored.  This is generally fine
for the synchronous functions that return ```Void``` (like most completion handlers).
Because the functions are called asynchronously, you have to process the return
values asynchronously as well:

```swift
dispatch_async(someQueue) {

    // syncReturnsParam(p: 3) is called on the main thread
    // Its response is also handled on the main thread
    syncReturnsParam +>> (p: 3) +>> { i in print(i) } // prints 4

    // syncReturnsParam(p: 3) is called on the main thread
    // Its response is handled on the global concurrent background queue
    // Note the positions and difference between +>> and ~>>
    syncReturnsParam +>> (p: 3) ~>> { i in print(i) } // prints 4

    // syncReturnsParamTuple(p: 3) is called on the global concurrent background queue
    // Its response is handled on an instantiated queue
    syncReturnsParamTuple ~>> (p: 3) ~>> otherQueue ~>> { iInt, iStr in print(pInt) }

    // Using the more functional style
    syncReturnsParam~>>.on(otherQueue).async(p: 3) +>> { i in print(i) }    
}
```

### Optionals ###

When the function you are routing is an optional, you must use the ```?~>>``` and ```?+>>```
operators when referencing the function:

```swift
func myTest(param: Int, completionHandler: (Int -> Int)? = nil) {

    // These will cause a compiler error because the handler is optional:
    completionHandler +>> (param)
    completionHandler+>>.async(param) +>> { i in print(i) }

    // Instead use these:
    completionHandler ?+>> (param)
    completionHandler?~>>.async(param)

    // For anything past the initial function, use normal operators:
    //     (+>> instead of ?+>>) --v
    completionHandler ?+>> (param) +>> { i in print(i) }

}
```

### Routing a Block Synchronously to Another Queue ###

Using the functional syntax, you can route a function (or any block) to another
thread while the calling thread waits.  This can be very useful for cases where
we want to update UI, or some other main-thread-dependent resource from a background
thread.

```swift
dispatch_async(someQueue) {
    // In the middle of some background code we want to change the UI

    // This does it asynchronously (both are the same):
    { self.label.hidden = true }+>>();
    { self.label.hidden = true }+>>.async();

    // This does it synchronously (call waits until change is made)
    { self.label.hidden = true }+>>.sync();

    // The above statement is equivalent to
    dispatch_main_sync {
        self.label.hidden = true
    }
}
```

*Note that because of the Swift compiler, you may need to include a semicolon on the line
before you create a statement with a block as the left-most expression.*

## Versioning ##

To help with Cocoapods versioning syntax, all versions of Brisk compatible with Swift 2.2 will begin with Major/Minor 2.2.  All versions comptible with Swift 2.3 will begin with Major/Minor 2.3.  All versions compatible with Swift 3.0 will begin with Major/Minor 3.0, etc.

This means your Cocoapod inclusion can look like:

```
pod 'Brisk', '~> 2.2' # Latest version compatible with Swift 2.2
pod 'Brisk', '~> 2.3' # Latest version compatible with Swift 2.3
pod 'Brisk', '~> 3.0' # Latest version compatible with Swift 3.0
```
