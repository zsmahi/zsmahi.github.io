---
title: EP06- How to get rid of primitive obsession
author: zsmahi
date: 2024-03-09 22:00:00 +0200
categories: [Blogging, Coding]
tags: [coding,c#, clean code]
pin: true
math: true
mermaid: true
image:
  path: /assets/img/posts/20240309/PrimitiveObsession.png
---

## Introduction

Greetings, fellow developers!

In this post, we delve into a pervasive issue that many of us encounter in our coding journey. Our aim is not to point fingers but to shine a light on this common "bad habit" and explore ways to overcome it.

Today, we're tackling the topic of **Primitive Obsession**.

## What Is Primitive Obsession?

First off, let's define what we mean by "primitives." In most programming languages, primitives are the bread and butter data types, including **strings**, **integers**, **floats**, and **booleans**.

**Primitive Obsession** is a term used in object-oriented programming to describe the overreliance on these basic data types instead of utilizing more fitting classes for handling complex data. But what does this mean in practice?

Let’s examine a well-known piece of code:

```cs
  public static void SendEmail(string recipientEmail, string subject, string body)
  {
    try
    {
      var smtpClient = new SmtpClient(SMTP.Server)
      {
        Port = 587,
        Credentials = new NetworkCredential(SMTP.UserName, SMTP.Password),
        EnableSsl = true
      };
      
      var mailMessage = new MailMessage
      {
        From = new MailAddress(SMTP.SenderAddress),
        Subject = subject,
        Body = body,
        IsBodyHtml = true
      };
      
      mailMessage.To.Add(recipientEmail);
      smtpClient.Send(mailMessage);
      
      Console.WriteLine("Email sent successfully!");
    }
    catch (Exception ex)
    {
      Console.WriteLine($"Error sending email: {ex.Message}");
    }
  }
```

This method sends an email, but it indiscriminately accepts any string as the recipient's email address. This lack of discrimination means that invalid addresses (e.g., "aazaea", "", "client@server.com", or null) can be passed along, only to potentially cause issues when the "Send" method is called.

**So, what's the remedy?**

Initially, one might consider inserting "guard clauses" directly into the SendEmail method to ensure all strings are validated before proceeding:

```cs
  public static void SendEmail(string recipientEmail, string subject, string body)
  {
    if (string.IsNullOrWhiteSpace(recipientEmail))
    {
      throw new ArgumentException("email address cannot be null or empty", nameof(recipientEmail));
    }

    Regex validateEmailRegex = new Regex("^\\S+@\\S+\\.\\S+$");
    if (!validateEmailRegex.IsMatch(recipientEmail))
    {
      throw new ArgumentException($" {recipientEmail} is not a valid email", nameof(recipientEmail));
    }
    // the rest of code
  }
```

While this ensures the validity of the recipient's email, it burdens a method—whose primary purpose is to send emails—with validation responsibilities. This not only violates the **Single Responsibility Principle (SRP)** but also makes the code harder to maintain and extend.

A more elegant solution involves externalizing the validation logic. Instead of embedding it directly within the SendEmail method, we can employ a dedicated utility class or function for email validation. This approach honors the SRP and keeps our methods focused on their intended tasks.

```cs
public class EmailValidator
{
  public static bool IsValidEmail(string email)
  {
    if (string.IsNullOrWhiteSpace(email))
    {
      return false;
    }
    
    Regex validateEmailRegex = new Regex("^\\S+@\\S+\\.\\S+$");
    return validateEmailRegex.IsMatch(email);
  }
}
```

But here's a thought: what if one forgets to call *IsValidEmail* before *SendEmail*?

Now, Let's examine a similar scenario involving Identifiers.

Suppose we have a service method responsible for retrieving user information by ID. It calls a repository method to fetch the data from the datastore and then transforms it into a DTO. The method might look something like this, assuming we have a DTO class UserDto and that the method wraps the output in a Result object:

```cs
public class UserService
{
  public Result<UserDto> GetById(int id)
  {
    if (id <= 0)
    {
      return Result.Failure<UserDto>(InvalidIdError);
    }

    User user = _repository.FirstOrDefault(user => user.Id == id);
    if (user is null)
    {
      return Result.Failure<UserDto>(NotFoundError);
    }

    return Result.Success<UserDto>(user.ToDto());
  }
}
```

This implementation is logically sound, as it first validates the ID (ensuring it's positive), then fetches the user from the database using this ID, and, if found, transforms the answer into the desired response format.

However, much like in the first example, this method's signature is misleading. It implies acceptance of any integer, including 0 or negative numbers, despite such inputs being logically invalid in this context. Thankfully, instead of throwing exceptions, it returns a "Failure" result, allowing developers to handle these cases gracefully and provide user-friendly feedback.

But herein lies the issue!

Imagine we now wish to add a method for updating user information:

```cs
public class UserService
{
  public Result<UserDto> UpdateUser(UpdateUserDto dto)
  {
    if (dto.Id <= 0)
    {
      return Result.Failure<UserDto>(InvalidIdError);
    }

    User user = _repository.FirstOrDefault(user => user.Id == dto.Id);
    if (user is null)
    {
      return Result.Failure<UserDto>(NotFoundError);
    }

    /*
    The update process that updates user with UpdateUserDto 
    */

    _repository.Update(user);
    unitOfWork.SaveChanges();
    return Result.Success<UserDto>(user.ToDto());
  }
}
```

Notice how we also check if a valid ID has been provided, which becomes repetitive and burdensome, indicating a deeper issue with our approach.

If you're starting to see a pattern here, you've identified the essence of primitive obsession. The issue isn't just about using primitive data types; it's about how their use can lead to code that is less clear, more error-prone, and harder to maintain.

## Why Is It a Problem?

The issue with Primitive Obsession isn't about using primitive types; it's about misusing them. Here's why it's problematic:

- **Lack of Clarity**: Using primitives for complex concepts makes the code harder to understand at a glance. For instance, representing an email as a string.
- **Validation Scattering**: Validation logic tends to get duplicated across the codebase. Every method that takes a string email needs to validate it, leading to code repetition and potential inconsistency (no respect of **DRY (Don't Repeat Yourself)** principle).
- **Missing Domain Concepts**: It leads to missed opportunities for encapsulating behaviors and validations specific to a domain entity, making the code less self-explanatory and harder to maintain.

### Is It a Code Smell?

Absolutely. Primitive Obsession is a code smell because it indicates a deeper design issue that could make the codebase difficult to maintain and extend. It suggests that the code is not taking full advantage of object-oriented principles, leading to a design that is less intuitive and more prone to errors.

## How to Rid Your Code of Primitive Obsession

Overcoming Primitive Obsession involves recognizing when you're using primitives as a crutch and taking steps to refactor your code towards a more object-oriented approach. Let's walk through some strategies:

## Introduce value objects

[**Value objects**](https://martinfowler.com/bliki/ValueObject.html) are a powerful antidote to primitive obsession. These immutable objects, which Martin Fowler discusses in his book "*Patterns of Enterprise Application Architecture*," are defined not by their identity but rather their attributes. Utilizing value objects for concepts such as email addresses, monetary values, or dates enables us to encapsulate related validation logic and operations within these objects, promoting cleaner and more expressive code.

For instance, rather than using a string to represent an email, consider a dedicated Email class:

```cs
public class Email
{
  public string Address { get; }
  
  public Email(string address)
  {
    if (string.IsNullOrWhiteSpace(recipientEmail))
    {
      throw new ArgumentException("email address cannot be null or empty", nameof(recipientEmail));
    }

    Regex validateEmailRegex = new Regex("^\\S+@\\S+\\.\\S+$");
    if (!validateEmailRegex.IsMatch(recipientEmail))
    {
      throw new ArgumentException($" {recipientEmail} is not a valid email", nameof(recipientEmail));
    }
    
    Address = address;
  }
    /* implicit operators are added only to simplify conversion to and from Email record */
    public static implicit operator string(Email email)
        => email.Address;

    public static implicit operator Email(string address)
        => new(address);

  public override string ToString() => Address;
}
```

With **C# 9.0**, using records for value objects like Email simplifies their creation and use, ensuring immutability and with it, greater reliability and predictability of your code. Moreover, by defining implicit conversions, we can seamlessly integrate these objects into existing codebases, minimizing the friction typically associated with refactoring efforts.

```cs
public record Email
{
    public string Address { get; }

    public Email(string address)
    {
        if (string.IsNullOrWhiteSpace(address))
        {
            throw new ArgumentException("Email cannot be null or empty", nameof(address));
        }

        if (!new Regex("^\\S+@\\S+\\.\\S+$").IsMatch(address))
        {
            throw new ArgumentException("Email is not a valid email", nameof(address));
        }

        Address = address;
    }
    /* implicit operators are added only to simplify conversion to and from Email record */
    public static implicit operator string(Email email)
        => email.Address;

    public static implicit operator Email(string address)
        => new(address);
}
```

### Leveraging Value Objects in Practice

By employing value objects, we can significantly improve our method signatures and internal logic, making our code more self-documenting and robust. Consider the refactored SendEmail method:

```cs
  public static void SendEmail(Email recipientEmail, string subject, string body)
  {
    try
    {
      var smtpClient = new SmtpClient(SMTP.Server)
      {
        Port = 587,
        Credentials = new NetworkCredential(SMTP.UserName, SMTP.Password),
        EnableSsl = true
      };
      
      var mailMessage = new MailMessage
      {
        From = new MailAddress(SMTP.SenderAddress),
        Subject = subject,
        Body = body,
        IsBodyHtml = true
      };
      
      mailMessage.To.Add(recipientEmail);
      smtpClient.Send(mailMessage);
      
      Console.WriteLine("Email sent successfully!");
    }
    catch (Exception ex)
    {
      Console.WriteLine($"Error sending email: {ex.Message}");
    }
  }
```

The introduction of the Email class as a method parameter immediately clarifies the expected input and enforces proper validation at the point of use, significantly reducing the potential for error.

## Use Strongly Typed IDs

In addition to value objects for complex types like email addresses, adopting strongly typed IDs is another effective strategy to combat primitive obsession. This approach involves defining specific types for identifiers, which can significantly enhance type safety and clarity throughout your codebase.

For example, instead of using a generic **int** for user IDs, you can define a **UserId** type:

```cs
  public readonly struct UserId
  {
    public UserId(int value)
    {
        if (value <= 0)
        {
            throw new ArgumentException("Id cannot be less than or equal to 0", nameof(value));
        }

        Value = value;
    }

    public int Value { get; }

    // Optional: Overriding ToString for easier debugging and logging
    public override string ToString() => Value.ToString();

    // Optional: Implicit conversion operators can simplify usage with existing APIs expecting an int
    public static implicit operator int(UserId userId) => userId.Value;
    public static implicit operator UserId(int value) => new UserId(value);
  }
```

Using a *UserId* struct not only ensures that IDs are always valid (e.g., positive integers) but also prevents mixing IDs of different entities, such as confusing a ProductId with a UserId. This approach adds a layer of compile-time type safety that can prevent bugs and make your code more self-documenting.

### Implementing Strongly Typed IDs

Incorporating strongly typed IDs into your code can be straightforward. Here's an example of how a UserService might utilize the UserId type:

```cs
  public class UserService
  {
    public Result<UserDto> GetById(UserId id)
    {
        // No need to check if id is less than or equal to 0 here since UserId enforces this constraint
        User user = _repository.FirstOrDefault(user => user.Id == id);
        if (user == null)
        {
            return Result.Failure<UserDto>("User not found.");
        }

        return Result.Success(user.ToDto());
    }

    // Other service methods can similarly benefit from the clarity and safety of using UserId
  }
```

By implementing strongly typed IDs, you make your methods' expectations clear and enforce important domain rules automatically, leading to a codebase that's easier to understand and maintain.

## Enumerations for Category Values

Another strategy to combat primitive obsession, particularly when working with a fixed set of values, is the use of enumerations. Enumerations, or enums, offer a type-safe way to work with such sets, making your code more readable and reducing the risk of invalid values.

For instance, consider user roles within an application. Instead of representing roles as strings or integers, which can be error-prone and unclear, define them as an enum:

```cs
  public enum UserRole
  {
    Admin,
    User,
    Guest
  }
```

### Applying Enums in Practice

Here’s how you might apply enums in a user management context:

```cs
  public class User
  {
    public UserRole Role { get; set; }
    
    public User(UserRole role)
    {
        Role = role;
    }
  }

  public class UserService
  {
    public void AssignRole(User user, UserRole newRole)
    {
        user.Role = newRole;
        Console.WriteLine($"User role updated to: {newRole}");
    }
  }
```

This approach ensures that roles are always assigned valid values, enhancing the reliability and maintainability of your code.

## Leverage Custom Collections

When dealing with sets of objects where additional behaviors or constraints are necessary, simply using generic collections like List&lt;T&gt; or Dictionary&lt;TKey, TValue&gt; might not be sufficient. Instead, creating custom collection classes allows you to encapsulate specific rules and behaviors, providing clearer intent and preventing misuse.

**Why Custom Collections?**

Custom collections go beyond the capabilities of generic collections by allowing you to:

- Enforce domain-specific rules, such as uniqueness or ordering.
- Hide complex operations behind simpler interfaces, improving code readability.
- Encapsulate data manipulation logic within the collection, adhering to the Single Responsibility Principle.

For instance, managing a collection of *Email* objects might require ensuring that each email is unique within the collection. A custom collection can transparently handle this requirement:

```cs
public class EmailCollection
{
    private readonly HashSet<Email> _emails = new HashSet<Email>();

    public bool Add(Email email)
    {
        // Adds email if not already present, enforcing uniqueness
        return _emails.Add(email);
    }

    // Additional custom behaviors can be defined as needed
}
```

This EmailCollection class uses a HashSet&lt;Email&gt; internally to store emails, leveraging the HashSet's inherent uniqueness constraint. By providing an Add method, it offers a clear and simple interface for adding emails, abstracting away the underlying complexity of checking for duplicates.

### Benefits of Custom Collections

The primary benefit of custom collections is their ability to ensure data integrity and enforce domain-specific rules automatically. By using these specialized classes, developers can prevent common mistakes and make the codebase easier to understand and maintain.

Moreover, custom collections can evolve over time to address new requirements without impacting the broader codebase. This flexibility makes them a valuable tool in the software developer's arsenal, especially when dealing with complex domain models.

## Method Parameters as Objects

A frequent manifestation of primitive obsession occurs in method signatures bloated with multiple primitive parameters. This not only clutters the method signature but also increases the likelihood of errors, such as parameter mix-ups, and makes the method less flexible to changes.

### Refactoring with Parameter Objects

Refactoring by grouping related parameters into a single object can dramatically increase the clarity and maintainability of your code. This pattern, often referred to as "Parameter Object", encapsulates several data points into a single object, thus simplifying method signatures and making the code more self-documenting.

Consider the following refactoring example:

**Before Refactoring:**

A method signature overloaded with primitive parameters, which can be confusing and error-prone.

```cs
public void AddPerson(string firstName, string lastName, string email)
{
    // Implementation
}
```

**After Refactoring:**

Grouping related parameters into a PersonDetails class simplifies the method signature and enhances code readability.

```cs
public class PersonDetails
{
    public string FirstName { get; }
    public string LastName { get; }
    public Email Email { get; } // Assuming Email is a value object defined earlier

    public PersonDetails(string firstName, string lastName, Email email)
    {
        FirstName = firstName;
        LastName = lastName;
        Email = email;
    }
}

public void AddPerson(PersonDetails details)
{
    // Implementation can now work with a single, cohesive object
}
```

This refactoring offers several benefits:

- Reduced Complexity: Simplifies the method signature by replacing multiple parameters with a single object.
- Increased Flexibility: Changes to the data structure require modifications in only one place, rather than in every method signature.
- Improved Code Readability: The PersonDetails class acts as documentation, clearly indicating the purpose and usage of the encapsulated data.

#### Applying the Strategy

Whenever you encounter a method that requires multiple data points, consider whether these parameters share a logical relationship that would benefit from encapsulation in a parameter object. This not only applies to data creation methods like AddPerson but also to any method that performs operations on multiple related data points.

## Wrapping Up

Addressing primitive obsession through strategies like value objects, strongly typed IDs, enumerations, custom collections, and parameter objects paves the way for cleaner, more maintainable code. These practices enhance clarity, enforce domain rules, and reduce errors, contributing to a more robust and understandable codebase.

As you refactor existing code or approach new projects, remember these strategies as tools to combat the pitfalls of primitive obsession. Embracing these patterns can significantly improve your code's quality and your effectiveness as a developer.

The journey to mastering software development is ongoing, and each step toward overcoming common issues like primitive obsession is a step toward clearer, more elegant code. Happy coding!

## Bonus 1: Generic ValueObject class

If you are interested with value objects, I share with you this implementation of generic value object that you can use a base for all of your value objects:

```cs
public abstract class ValueObject : IEquatable<ValueObject>
{
    private const PrimitiveNumber = 23;
    public static bool operator !=(ValueObject a, ValueObject b)
        => !(a == b);

    public static bool operator ==(ValueObject a, ValueObject b)
    {
        if (a is null && b is null)
            return true;

        if (a is null || b is null)
            return false;

        return a.Equals(b);
    }

    public override bool Equals(object? obj)
    {
        if (obj == null)
            return false;

        if (GetType() != obj.GetType())
            return false;

        var valueObject = (ValueObject)obj;

        return GetEqualityComponents().SequenceEqual(valueObject.GetEqualityComponents());
    }

    public bool Equals(ValueObject? other)
        => Equals(other as object);

    public override int GetHashCode()
    {
        return GetEqualityComponents()
            .Aggregate(1, (current, obj) =>
            {
                unchecked
                {
                    return (current * PrimitiveNumber) + (obj?.GetHashCode() ?? 0);
                }
            });
    }

    protected virtual IEnumerable<object> GetEqualityComponents()
    {
        // Use reflection to get all the properties of the object.
        PropertyInfo[] properties = GetType().GetProperties(BindingFlags.Instance | BindingFlags.Public);
        return
        // Return the value of each property.
        from property in properties
        select property.GetValue(this);
    }
}
```

you can now use it like this :

```cs
public class Email : ValueObject
{
    public Email(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new ArgumentException("Email cannot be null or empty", nameof(value));
        }

        if (!new Regex("^\\S+@\\S+\\.\\S+$").IsMatch(value))
        {
            throw new ArgumentException("Email is not a valid email", nameof(value));
        }

        Value = value;
    }

    public string Value { get; }

    protected override IEnumerable<object> GetEqualityComponents()
    {
        yield return Value;
    }
}
```

## Bonus 2: Generic StronglyTypedId struct

I share with you this implementation of generic StronglyTypedId for all of your strongly typed Ids:

```cs
public abstract class StronglyTypedId<TValue> where TValue : notnull
{
    protected StronglyTypedId(TValue value)
    {
        if (!IsValid(value))
        {
            throw new ArgumentException($"{value} is not a valid value for this id");
        }

        Value = value;
    }

    public TValue Value { get; }

    public static bool operator !=(StronglyTypedId<TValue> left, StronglyTypedId<TValue> right)
      => !(left == right);

    public static bool operator ==(StronglyTypedId<TValue> left, StronglyTypedId<TValue> right)
      => left.Equals(right);

    public override bool Equals(object? obj)
      => obj is StronglyTypedId<TValue> other && Value.Equals(other.Value);

    public override int GetHashCode()
      => Value.GetHashCode();

    public abstract bool IsValid(TValue value);

    public override string ToString()
        => Value.ToString() ?? string.Empty;
}
```

ou can now use it like this :

```cs
public class UserId : StronglyTypedId<int>
{
    public UserId(int value) : base(value)
    {
    }

    public static UserId From(int value) => new UserId(value);

    public static implicit operator int(UserId self) => self.Value;

    public static implicit operator UserId(int value) => new UserId(value);

    public override bool IsValid(int value) => value > 0;
}
```

## Gist {#gist}

I've shared the code of the two generic classes as a gist

{% gist dcced370c876dab5acd969208063391a %}

that's all folks! Keep your code cleaner :grinning:
