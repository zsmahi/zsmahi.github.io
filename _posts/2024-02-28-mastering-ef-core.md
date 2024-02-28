---
title: EP05- Mastering EF Core- Deep Dive into Entity-to-Database Mapping
author: zsmahi
date: 2024-02-28 21:00:00 +0200
categories: [Blogging, Coding]
tags: [coding,c#]
pin: true
math: true
mermaid: true
image:
  path: /assets/img/posts/20240228/EFCore.png
---

## Introduction

Hello, fellow developers!

In the realm of .NET development, Entity Framework Core (EF Core) stands as a beacon of efficiency and elegance, providing a bridge between the object-oriented world of .NET entities and the relational universe of databases. This post embarks on an in-depth exploration of how EF Core navigates the complex process of mapping entities to database objects, offering insights that not only demystify the inner workings of this powerful ORM but also position this guide as a premier resource in the domain.

## The Essence of EF Core Mapping

At its core, EF Core operates on a simple premise: transforming your C# entities into SQL commands that interact with a database. This transformation, however, is anything but trivial. It encompasses a sophisticated interplay of conventions, configurations, and mappings that ensure your application's data access layer is both robust and flexible.

### Automatic Conventions: The Starting Point

EF Core's journey begins with conventions. By adhering to a set of predefined rules, EF Core automatically infers the database schema based on your entity classes. This includes guessing table names from your DbSet properties, column names from your entity properties, and relationships based on your navigation properties. These conventions provide a smooth start, requiring minimal configuration for many applications.

Consider an entity class "Blog":

```cs
public class Blog
{
    public int BlogId { get; set; }
    public string Url { get; set; }
    public List<Post> Posts { get; set; }
}
```

By convention, EF Core maps this class to a Blogs table, with "BlogId" as the primary key and "Url" as a column. The Posts collection indicates a one-to-many relationship with a Post entity.

### Configurations: Taking Control

While conventions cover a wide array of scenarios, real-world applications often demand a more nuanced approach. This is where EF Core's configuration mechanisms shine, offering two main paths: Data Annotations and Fluent API.

#### Data Annotations: Simple Yet Powerful

Data Annotations allow developers to refine the entity-to-database mapping directly within entity classes using attributes. This method is straightforward and keeps the configuration close to the class definitions, making it easy to see how properties are mapped at a glance.

Let's take a look at an example:

```cs
public class Blog
{
    [Key]
    public int BlogId { get; set; }

    [Required]
    [MaxLength(200)]
    public string Url { get; set; }
}
```

Here, "[Key]" specifies BlogId as the primary key, while "[Required]" and "[MaxLength]" apply constraints to the Url column.

#### Fluent API: Precision and Flexibility

For those seeking finer control over their mappings, the Fluent API is a treasure trove. It not only covers the ground that Data Annotations do but also delves into more complex scenarios. From specifying property types and constraints to configuring relationships with precision, the Fluent API empowers developers to sculpt their data access layer with meticulous detail.

Example: Configuring a One-to-Many Relationship:

```cs
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<Blog>()
        .HasMany(b => b.Posts)
        .WithOne(p => p.Blog)
        .HasForeignKey(p => p.BlogId);
}
```

This configuration defines the one-to-many relationship between "Blog" and "Post", specifying "BlogId" as the foreign key.

### Digging Deeper: Beyond Public Properties

A distinctive feature of EF Core is its ability to map not just public properties but also private fields using reflection. This capability supports a more encapsulated design, allowing entities to shield their state behind well-defined methods while still enabling EF Core to persist their state. Through explicit configuration via the Fluent API, EF Core can access these private members using reflection, marrying the principles of encapsulation with the practical needs of data persistence.

Let's take a look at this example:

Assume you have a private field _createdDate in your Blog entity that you don't want to expose publicly:

```cs
public class Blog
{
    public int BlogId { get; set; }
    private DateTime _createdDate = DateTime.Now;
}
```

You can configure EF Core to map this field to a column using the Fluent API:

```cs
modelBuilder.Entity<Blog>()
    .Property<DateTime>("_createdDate")
    .HasColumnName("CreatedDate");
```

This configuration ensures _createdDate is mapped to a CreatedDate column in the database.

#### Limitations and Considerations

- Reflection Performance: While direct field access is powerful, using reflection to access private fields can have performance implications. EF Core is optimized to minimize the overhead, but it's something to be aware of in performance-critical applications.

- Design Trade-offs: Although accessing private fields supports encapsulation, it also means that any logic in property accessors is bypassed. Ensure that this does not bypass important business logic that should be executed during property access.

## Relationships: The Fabric of Data

EF Core excels in mapping the complex web of relationships between entities. Whether it's one-to-one, one-to-many, or many-to-many, EF Core uses navigation properties to infer relationships, defaulting to conventions that can be overridden for granular control. The introduction of first-class support for many-to-many relationships in recent versions simplifies what was once a cumbersome process, eliminating the need for a join entity in many cases.

```cs
public class Blog
{
    public int BlogId { get; set; }
    public List<Post> Posts { get; set; }
}

public class Post
{
    public int PostId { get; set; }
    public string Title { get; set; }
    public List<Blog> Blogs { get; set; }
}

modelBuilder.Entity<Blog>()
    .HasMany(b => b.Posts)
    .WithMany(p => p.Blogs);

```

This setup automatically creates a join table to facilitate the many-to-many relationship between "Blog" and "Post".

## Advanced Configurations: The Devil in the Details

EF Core's mapping capabilities extend into more advanced territories, such as:

### Global Query Filters

Global Query Filters allow you to define query-level filters that are automatically applied to all queries involving a particular entity type. This feature is incredibly useful for implementing patterns such as soft delete or multi-tenancy.

Example: Implementing Soft Delete

First, add a IsDeleted property to your entity class, which will be used by the global query filter.

```cs
public class Post
{
    public int PostId { get; set; }
    public string Title { get; set; }
    public bool IsDeleted { get; set; } // Soft delete flag
}
```

Then, configure the global query filter in your DbContext:

```cs
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<Post>().HasQueryFilter(p => !p.IsDeleted);
}
```

With this configuration, EF Core automatically filters out any Post entities where "IsDeleted" is true, effectively implementing a soft delete mechanism.

### Owned Entities and Value Objects

EF Core allows you to treat complex types as part of the owning entity in the database, simplifying the management of value objects in your domain model.

Example: Configuring an Owned Entity

Imagine you have a Address value object that is used by your User entity:

```cs
public class User
{
    public int UserId { get; set; }
    public Address HomeAddress { get; set; }
}

public record Address(
    string Country,
    string State,
    string ZipCode,
    string City,
    string Street);
```

To configure Address as an owned entity, you can use the Owned attribute or the Fluent API:

```cs
  modelBuilder.Entity<User>().OwnsOne(u => u.HomeAddress);
```

This configuration tells EF Core to treat Address as part of the User entity, storing its properties in the same table as User but handling them as a complex value object.

### Shadow Properties

Shadow Properties are fields in your model that are not defined in your entity class but are present in the database schema. They're useful for tracking changes or adding audit fields without cluttering your entity model.

Example: Adding a Created Timestamp Shadow Property

Let's add a shadow property to the Post entity for tracking when a post was created:

```cs
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<Post>().Property<DateTime>("CreatedTimestamp");
}
```

You can then set the value of this shadow property in your application logic, for example, before saving changes:

```cs
context.Entry(post).Property("CreatedTimestamp").CurrentValue = DateTime.UtcNow;
```

This approach allows you to maintain audit information in your database without having to include these properties in your entity class, keeping your domain model clean and focused on the business logic.

## Conclusion: A Symphony of Code and Data

Entity Framework Core's entity-to-database mapping is a symphony of code and data, orchestrated through a combination of conventions, explicit configurations, and an understanding of .NET's rich type system. This deep dive reveals the power and flexibility of EF Core, showcasing its ability to adapt to a wide range of scenarios from simple CRUD operations to complex domain-driven designs. Armed with this knowledge, developers can harness EF Core to build data access layers that are both powerful and elegant, ensuring their applications perform efficiently and effectively in any environment.

As we've explored the depths of EF Core's mapping capabilities, it's clear that this ORM is not just a tool but a craftsman's workshop, offering everything needed to bridge the object-relational divide with grace and precision. This guide, rich in detail and filled with insights, aims to equip you with the knowledge to master EF Core, setting a new standard for excellence in the world of .NET development.

that's all folks!
