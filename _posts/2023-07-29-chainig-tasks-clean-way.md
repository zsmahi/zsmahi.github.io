---
title: EP04- Improving Asynchronous Programming in C# with Fluent API Style Task Chaining
author: zsmahi
date: 2023-07-29 21:00:00 +0200
categories: [Blogging, Coding]
tags: [coding,c#]
pin: true
math: true
mermaid: true
image:
  path: /assets/img/posts/20230729/TaskTrick.png
---

## Introduction

Hello, fellow developers!

Modern C# development heavily leans on asynchronous programming models, especially when dealing with **I/O operations** or **services** that may cause your application to pause or block while waiting for the response. Using the **Task-based asynchronous pattern (TAP)** with **async** and **await** keywords has become a standard way to perform such operations.

However, when dealing with a series of related tasks that need to be performed in sequence, code readability and error handling can be a bit of a challenge.

Today, I want to share a technique that helped me to achieve in clean and fluent manner using [**extension methods**](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/extension-methods). So stay tunned :grinning:

## TL;DR

I've shared the code of this post as a gist. [Jump to Gist](#gist)


## Existing solution

Before showing my technique, I'm gonna talk about an existing native solution in Task class, and what are its pros and cons.

#### The native method ContinueWith

Microsoft has already a way to handle chainig tasks using the [**ContinueWith Method**](https://learn.microsoft.com/en-us/dotnet/standard/parallel-programming/chaining-tasks-by-using-continuation-tasks).

The **ContinueWith** method is a method on the **Task** class that allows us to register a continuation function that will be executed when the task completes. The continuation function can be used to do something with the result of the task, or to handle any exceptions that were thrown by the task.

The ContinueWith method has multiple overloads [**check here**](https://learn.microsoft.com/en-us/dotnet/api/system.threading.tasks.task.continuewith?view=net-7.0):

Let's take a look at an example:

```cs
Task<int> t = Task.Run(() => {
    // This is the first task
    // We are just returning a simple integer
    return 42;
}).ContinueWith((i) => {
    // This task will be run when the first task finishes.
    // The result of the first task is available as i.Result
    Console.WriteLine("The answer is " + i.Result);
});

// Wait for the second task to finish
t.Wait();
```

In this code, we start a task that runs a function returning 42. Then we use **ContinueWith** to chain another task that is executed when the first task finishes. The **ContinueWith** method takes as an argument a function that takes the previous task as its parameter. The Result property of this parameter is used to get the result of the previous task.

The **ContinueWith** method also returns a **Task** (or a **Task&lt;TRsult&gt;**), allowing you to chain multiple continuations like so:

```cs
// Using ContinueWith
var result = await FirstOperationAsync(1)
    .ContinueWith(t1 => SecondOperationAsync(t1.Result))
    .Unwrap()
    .ContinueWith(t2 => ThirdOperationAsync(t2.Result))
    .Unwrap();
```

As you the **ContinueWith** method helped us to chain tasks together and I want to say it's good for small cases; but whenever it comes to more complex cases, these method will have some limitations.

- **Syntax and Readability:** **ContinueWith** creates a new task that will start when the antecedent task (the task that the ContinueWith method is called on) completes. This involves creating a new **Task** instance, which, when used repeatedly, can lead to code that is more difficult to read and maintain.
- **Exception Handling**: **ContinueWith** does not automatically propagate exceptions from the antecedent task. It wraps them in an AggregateException, which you need to manually handle.
- **Cancellation Handling**: With the **ContinueWith** method, you must check if a task was cancelled by checking the task's state in the continuation.

So what's the solution ?

## The solution

If you came form **JavaScript** world or at least you are comfortable with it, you have probably used the **JavaScript's Promises** that allow easy chaining of asynchronous operations using **.then()** and **.catch()** methods.

In this blog post, we'll explore how to implement similar methods in C# **using extension methods** to chains tasks in more **readable** and **maitainable** manner with **good error handling**. So let's go!

## Creating the *Then* method

The **Then** method is a way of sequencing tasks. After one task completes, you use the result to start another task. Here's how to implement a basic Then method as an extension method for **Task&lt;T&gt;**:

```cs
public static async Task<TOut> Then<TIn, TOut>(
    this Task<TIn> task,
    Func<TIn, Task<TOut>> continuation,
    CancellationToken cancellationToken = default)
{
    // some guard clauses
    if (task == null)
    {
        throw new ArgumentNullException(nameof(task));
    }

    if (continuation == null)
    {
        throw new ArgumentNullException(nameof(continuation));
    }

    cancellationToken.ThrowIfCancellationRequested();

    TIn result = await task.ConfigureAwait(false);

    cancellationToken.ThrowIfCancellationRequested();

    return await continuation(result).ConfigureAwait(false);
}
```

Here, **Then** is defined as an extension method on **Task&lt;T&gt;**. It takes a function, **continuation**, which accepts the result of the first task and returns a new Task. In essence, the Then method enables you to start a new task using the result of the previous one, thereby chaining tasks together.

## Creating the *Catch* method

Error handling in Task-based asynchronous programming can be done using try-catch blocks, but with multiple tasks chained together, each with its own error handling, it can become unwieldy. We can improve this by creating a **Catch** method that centralizes error handling:

```cs
public static async Task<T> Catch<T>(
    this Task<T> task,
    Func<Exception, T> errorHandler,
    CancellationToken cancellationToken = default)
{
    // also another guard clause :p

    if (task == null)
    {
        throw new ArgumentNullException(nameof(task));
    }

    if (errorHandler == null)
    {
        throw new ArgumentNullException(nameof(errorHandler));
    }

    cancellationToken.ThrowIfCancellationRequested();

    try
    {
        return await task.ConfigureAwait(false);
    }
    catch (Exception ex)
    {
        T result = errorHandler(ex);
        cancellationToken.ThrowIfCancellationRequested();
        return result;
    }
}
```

This **Catch** method accepts an error handling function, **errorHandler**, which is invoked when an exception occurs in the task. By chaining a Catch call at the end of our task sequence, we can ensure that any errors thrown during the execution of our tasks will be passed to our errorHandler.

## Make all toghether to chain tasks

Now let's see how we can use these extension methods in practice. Assume we have three methods that perform some asynchronous operation:

```cs
  Task<string> FirstOperationAsync(int intParameter);
  Task<bool> SecondOperationAsync(string stringParameter);
  Task<int> ThirdOperationAsync(bool boolParameter);
```

We can chain these methods together as follows:

```cs
int result = await FirstOperationAsync(1)
    .Then(x => SecondOperationAsync(x))
    .Then(x => ThirdOperationAsync(x))
    .Catch(ex =>
    {
        Console.WriteLine(ex.Message);
        return -1; // return a default value in case of error
    });
```

With the **Then** and **Catch** methods, you can see how much cleaner the code looks compared to nested callbacks or consecutive awaits.

## Let's compare our Then-Catch strategy to ContinueWith

At the beginning of this post I've talked about **ContinueWith** limitations, now I'll talk about how can **Then-Catch** make chaining easier.

- **Syntax and Readability**: Our **Then** method takes a delegate that returns a **Task&lt;T&gt;** which makes the chaining look more seamless and the syntax cleaner, thereby improving code readability.
- **Exception Handling**: **Then** method propagates exceptions, and with the **Catch** method, you can centralize exception handling in a more intuitive and easy-to-understand way.
- **Cancellation Handling**: In the **Then** method, we can directly pass **CancellationToken** which will throw an **OperationCanceledException** if the token is cancelled, offering a more streamlined way of handling cancellations. (of course the **Catch** method will catch it :wink:)

## Conclusion

In the end, whether to use **ContinueWith**, our custom **Then-Catch** method, or any other chaining strategy largely depends on your specific use case and personal preference. Some developers may prefer the control and flexibility offered by ContinueWith, while others may find the readability and ease-of-use provided by **Then-Catch** to be more beneficial. Ultimately, the goal should be to write code that is easy to understand, maintain, and debug, and both **ContinueWith** and **Then-Catch** can be effective tools in achieving that goal, each in their own way.

## Gist {#gist}

I've shared the code seen in this post as a gist

{% gist 3e936893050ba740812eed63be9c3d77 %}

that's all folks! Keep your code cleaner :grinning:
