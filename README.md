![Brisk](/Assets/Banner.png)

Swift support for blocks and asynchronous code is powerful, but can lead to a maze of indented logic that
quickly becomes unreadable and error-prone.

Brisk offers two distinct but complimentary functions:

1. Extends the standard GCD library with several functions that help make standard usage a bit more concise.
2. Provides shorthand operators for swiveling the concurrency of your functions.

These might be best explained by code example.

#### Quick Look: Extending the GCD Library for Simplicity ####

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

#### Quick Look: Concurrency Swiveling ####

Consider the following hypothetical asynchronous API (using Swift 2.2 function syntax):

```swift
// API we're given:
func findClosestPokemonWithin(within: Double,
                   completionHandler: (pokemon: Pokemon?, error: NSError?))

func countPokeballs(completionHandler: (number: Int?, error: NSError?))

func throwPokeballAtPokemon(pokemon: Pokemon,
                  completionHandler: (success: Bool, error: NSError?))
```

Let's assume that all of the completion handlers are called on the main thread.  We want to
make this utility function:

```swift
// Utility we want:
func throwPokeballAtClosestPokemonWithin(within: Double,
                              completionHandler: (success: Bool, pokemon: Pokemon?, error: NSError?))
```

This function represents a common occurrence of chaining asynchronous functions into a helper utility for a single use case.
Using only the standard GCD library, your function might look like this:

```swift
// The old way...
func throwPokeballAtClosestPokemonWithin(within: Double,
                              completionHandler: (success: Bool, pokemon: Pokemon?, error: NSError?)) {
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
func throwPokeballAtClosestPokemonWithin(within: Double,
                              completionHandler: (success: Bool, pokemon: Pokemon?, error: NSError?)) {
    dispatch_bg_async {

        // Step 1
        let (pokemon, error) <<+{ findClosestPokemonWithin(within, completionHandler: $0) }
        guard let p = pokemon where error == nil else {
            return completionHandler +>> (success: false, error: error)
        }

        // Step 2
        let (number, error2) <<+{ countPokeballs($0) }
        guard let n = number where error == nil else {
            return completionHandler +>> (success: false, error: error2)
        }

        // Step 3
        let (success, error3) <<+{ throwPokeballAtPokemon(p, completionHandler: $0) }
        completionHandler +>> (success: success, error: error3)
    }
}
```

The main advantage with Brisk is that the asynchronous functions can be coded using a seemingly-synchronous flow.
The asynchronous nature of the methods is hidden behind the custom operators.  *Unlike PromiseKit, all return values
remain in scope as well*.
