---
title: A cool C# clean code trick
author: zsmahi
date: 2023-07-12 21:00:00 +0200
categories: [Blogging, Coding]
tags: [coding,c#]
pin: true
math: true
mermaid: true
image:
  path: /assets/img/posts/20230712/trick.png
---

## Introduction

Hello, fellow developers!

Today, I want to share a technique that has the potential to make your C# code cleaner and more readable. We're going to talk about a custom extension method.

As you know; [**extension methods**](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/extension-methods) in C# allow us to add methods to existing types without creating a new derived type, recompiling, or otherwise modifying the original type.

## Let's see this in action

Consider a common scenario where we need to check if a specific item is one of many values. Normally, we'd use the **or** operator to check that see code below:

```cs
string fruit = "banana";
bool found = fruit == "banana" || fruit == "orange" || fruit == "apple";
```

At the end, the variable found will be true since item is a banana. the problem with this solution is that it's neither readable nor maintainable. I talk here whenever the number of items to check grows.

Another good solution would be to introuduce a collection (a C# List<> for example) and use the Contains method to check if the item is one of the items of collections (see code below)

```cs
using System.Collections.Generic;


List<string> fruits = new List<string>()
{
  "banana",
  "orange",
  "apple"
};
string fruit = "banana";
bool found = collection.Contains(fruit);
```

We can see now, that our code is more readable, and we no longer have the nasty **OR** operator, here we can say that the solution is much more better.


## But is it enough ?

Since I'm a perfectionnist :stuck_out_tongue: and always seeking for better code quality and performance, I can say that we can do better.

What if our item is not a string, a complexe object? Do we need to create a list each time we do a similar comparison ? is it a good way ? is it compatible **DRY** principle ?

After all these questions, we see that our previous solution is limited, and we're looking for more general solution, and this solution is quiete simple.

We will first use the power of extension methods to englobe that verification in a small beatutiful method and then we will see if we can make it more complete.

So as a first step we will introduce a generic extension method, let's call it **In** and exploit the power of the keyword **params**

Our method will look like that:


```cs
using System;
using System.Linq;
using System.Collections.Generic;

public static class ExtensionMethods
{
  public static bool In<T>(this T item, params T[] collection)
  {
    if (!collection.Any())
    {
      return false;
    }

    return collection.Contains(item);
  }
}
```



This method use the keyword **params** so we can add items as arguments separated with a comma ','

Now we can call it like that (of course after referencing the namespace of ExtensionMethods class)

```cs
string fruit = "banana";
bool found = fruit.In("apple","oranage"); // result will be false

found = fruit.In("apple","oranage","banana"); // result will be true

// we can add extra arguments

found = fruit.In("apple","oranage","banana","pear");
found = fruit.In("apple","oranage","banana","pear","melon");
```
As you see we've made our code cleaner and fluent, and we didn't need to create an extra object (the collection). The code does all of that in a readable way.

With the generic option **&lt;T&gt;** the method is usable with any C# type (type value or reference value).

Now, we will go deeper in our reflexion, and let's say we want the comparison to be case insensitive (in case of strings) or we want a complexe comparison, so how can we achieve that.

The solution is so easy !

We will use the overload method of Contains, that need an [**IEqualityComparer**](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.iequalitycomparer-1?view=net-7.0)

so the method will be like that:
```cs
public static bool In<T>(
  this T item,
  IEqualityComparer<T> comparer,
  params T[] collection
  )
{
  if (!collection.Any())
  {
    return false;
  }

  return collection.Contains(item, comparer);
}
```

As you see we introduced a third parameter **IEqualityComparer&lt;T&gt; comparer** that will handle the different types of comparison

an example:
```cs
string[] fruits = { "apple", "banana", "mango", "orange" };
string fruitToFind = "apple";

// Using custom IEqualityComparer<T>
bool result = fruitToFind.In(StringComparer.OrdinalIgnoreCase, fruits);
Console.WriteLine(result);  // Outputs: True
```

You can now use any Comparer that implements the **IEqualityComparer**, you can even write your own comparer :smile:

I've shared the code seen in this post as a gist

{% gist 8cc99f82930b6a553da38d4a471a79ff %}

that's all folks! Keep your code amazing :grinning:
