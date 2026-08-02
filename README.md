# OpenAPI Sorbet Rails

Generate Ruby classes with [Sorbet](https://sorbet.org/) types from an OpenAPI 3.1 document.

Each schema in your API description becomes a `T::Struct` laid out along Rails' autoloading
conventions, so a JSON payload described by the spec can be built, type-checked and serialized
as an ordinary Ruby object.

> **Status: work in progress.** `components` and the response bodies under `paths` are translated;
> request bodies and parameters are not. The gem has not been published to RubyGems yet. Expect
> breaking changes.

## Requirements

- Ruby >= 3.2
- `activesupport`, `sorbet-runtime`, `thor` (runtime dependencies of the gem)

The generated code also depends on `activesupport` and on this gem at runtime — see
[Runtime dependencies of generated code](#runtime-dependencies-of-generated-code).

## Installation

The gem is not on RubyGems.org yet, so install it from git:

```ruby
# Gemfile
gem "openapi_sorbet_rails", github: "yantene/openapi-sorbet-rails"
```

Generation is a development-time task, so `group :development` is usually the right place for it —
but note that the *generated* classes need this gem at runtime, so keep it in the default group if
you check the generated code into your application.

## Usage

### Command line

```console
$ openapi_sorbet_rails all example.yaml --prefix Foo::Bar::Api --output tmp/generated
Generated: Foo::Bar => tmp/generated/foo/bar.rb
Generated: Foo::Bar::Api => tmp/generated/foo/bar/api.rb
Generated: Foo::Bar::Api::Components::Schemas::Post => tmp/generated/foo/bar/api/components/schemas/post.rb
...
```

| Option | Alias | Description |
| --- | --- | --- |
| `--output DIR` | `-o` | Directory to write generated classes into. Defaults to `./app/api`. |
| `--prefix NAMESPACE` | `-p` | Namespace prefix for generated classes, e.g. `Foo::Bar::Api`. Omit it to generate top-level constants such as `Components::Schemas::Post`. |
| `--clean` | | Remove the output directory before generating. |

`--clean` deletes the output directory recursively, so point `--output` at a directory that holds
nothing but generated code.

### Ruby API

```ruby
require "openapi_sorbet_rails"

generator = OpenapiSorbetRails::Generator.from_file(
  api_spec_path: "openapi.yaml",
  output_dir: Rails.root.join("app/api_schemas"),
  namespace_prefix: "ApiSchemas"
)

generator.clean_up!
generator.generate_all!
```

| Method | Description |
| --- | --- |
| `generate_all!` | Generate everything: `components` (responses and schemas) plus response bodies under `paths`. |
| `generate_all_path_responses!` | Generate a type for every `application/json` response under `paths`. |
| `generate_all_schemas!` | Generate every entry of `components/schemas`. |
| `generate_schemas!(names:)` | Generate only the named entries of `components/schemas`. |
| `generate_all_responses!` | Generate every entry of `components/responses` that has an `application/json` body. |
| `generate_responses!(names:)` | Generate only the named entries of `components/responses`. |
| `clean_up!` | Delete the output directory. |

`Generator.new(api_spec:, output_dir:, namespace_prefix:)` takes an already-parsed spec — a hash
with symbol keys — if you do not want to read it from a file.

## Generated code

Given this fragment of [`example.yaml`](example.yaml):

```yaml
components:
  schemas:
    Post:
      type: object
      required:
        - id
        - content
        - createdAt
      properties:
        id:
          type: string
        content:
          type: string
        createdAt:
          type: string
          format: date-time
        metadata:
          $ref: "#/components/schemas/Metadata"
```

`openapi_sorbet_rails all example.yaml -p Foo::Bar::Api -o tmp/generated` writes
`tmp/generated/foo/bar/api/components/schemas/post.rb`:

```ruby
# frozen_string_literal: true
# typed: strict

class Foo::Bar::Api::Components::Schemas::Post < T::Struct
  extend T::Sig
  include OpenapiSorbetRails::Interface::Component

  const :id, String
  const :content, String
  const :created_at, String
  const :metadata, T.nilable(Foo::Bar::Api::Components::Schemas::Metadata)

  sig { override.returns(T::Hash[Symbol, T.untyped]) }
  def as_json
    {
      id: method(:id).call.as_json,
      content: method(:content).call.as_json,
      createdAt: method(:created_at).call.as_json,
      metadata: method(:metadata).call.as_json,
    }
  end
end

# ---
# type: object
# required:
# - id
# - content
# - createdAt
# properties:
#   id:
#     type: string
# ...
```

Three things to note:

- Property names are converted to `snake_case` for the Ruby attribute, while `as_json` emits the
  original key from the spec (`created_at` in Ruby, `createdAt` on the wire).
- A property that is not listed under `required` becomes `T.nilable(...)`.
- The schema it was generated from is appended as a comment, so the mapping stays traceable.

Every generated class includes `OpenapiSorbetRails::Interface::Component`, which requires an
`as_json` method — that is the contract the templates fulfil.

### Naming and file layout

Class names are derived from the position of the schema in the document, prefixed with
`--prefix`, and each class is written to the path Zeitwerk would expect:

| Spec location | Generated constant | File |
| --- | --- | --- |
| `components/schemas/Post` | `<Prefix>::Components::Schemas::Post` | `components/schemas/post.rb` |
| `components/responses/Foo` | `<Prefix>::Components::Responses::Foo` | `components/responses/foo.rb` |
| `paths` → `/posts/{postId}` → `get` → `200` | `<Prefix>::Paths::Posts::PostId::Get::Responses::Status200` | `paths/posts/post_id/get/responses/status200.rb` |

Anonymous subschemas are named after their position in the parent:

| Subschema | Generated constant |
| --- | --- |
| Inline object under property `metadata` | `<Parent>::Metadata` |
| *n*-th member of `oneOf` | `<Parent>::OneOf<n>` |
| *n*-th member of `allOf` | `<Parent>::AllOf<n>` |
| `items` of an array | `<Parent>::Item` |

An `allOf` schema becomes a struct holding one `const` per member (`all_of1`, `all_of2`, …) whose
`as_json` merges the members' JSON. A `oneOf` schema becomes a struct wrapping a single `value` of
type `T.any(...)`. Arrays do not get a class of their own — they are rendered inline as
`T::Array[...]`.

### Path responses

Each `application/json` response under `paths` is named after its position in the document: the
path template becomes a namespace (`{postId}` → `PostId`), the verb is capitalized, and the status
code becomes `Status200`. Responses without an `application/json` body — a `204`, say — are skipped,
and keys of a path item that are not operations (`parameters`, `summary`, `servers`) are ignored.

When the response body is defined inline, the generated constant is a `T::Struct` like any other
schema. When it is a `$ref` or an array, the type already lives elsewhere, so the constant is a type
alias pointing at it:

```ruby
# frozen_string_literal: true
# typed: strict

module Foo::Bar::Api::Paths::Posts::Get::Responses
  Status200 = T.type_alias { T::Array[Foo::Bar::Api::Components::Schemas::Post] }
end

# ---
# type: array
# items:
#   "$ref": "#/components/schemas/Post"
```

### Runtime dependencies of generated code

- This gem, for `OpenapiSorbetRails::Interface::Component`.
- `sorbet-runtime`, for `T::Struct`.
- `activesupport`, because primitive and `oneOf` wrappers use `delegate :as_json, to: :value`.
  Inside a Rails application this is already loaded.

## Supported schema constructs

| Construct | Status | Generated type |
| --- | --- | --- |
| `type: string` | Supported | `String` |
| `type: integer` | Supported | `Integer` |
| `type: number` | Supported | `Float` |
| `type: boolean` | Supported | `T::Boolean` |
| `type: "null"` | Supported | `NilClass` |
| `type: object` | Supported | `T::Struct` with one `const` per property |
| `type: array` | Supported | `T::Array[...]` |
| `oneOf` | Supported | `T.any(...)` |
| `allOf` | Supported | `T::Struct` merging each member |
| `$ref` | Supported | Reference to the corresponding generated class |
| `anyOf` | Not supported | Raises `UnsupportedSchemaError` |
| `not` | Not supported | Raises `UnsupportedSchemaError` |
| `enum` | Ignored | Falls back to the base type |
| `format`, `minimum`, `maxLength`, … | Ignored | Preserved only in the trailing comment |

Anything the generator does not understand raises `OpenapiSorbetRails::UnsupportedSchemaError`
with the offending schema, rather than silently emitting an untyped field.

## Limitations

- Under `paths`, only response bodies are translated. Request bodies and parameters are skipped.
- Responses are only generated when they carry an `application/json` body, both under `paths` and
  in `components/responses`.
- Validation keywords (`enum`, `format`, `minimum`, `pattern`, …) do not affect the generated
  types. The generated structs give you shape and nullability, not full spec validation.
- There is no deserialization helper yet — generated classes serialize (`as_json`) but do not
  parse an incoming payload back into a struct.
- Generated classes are never `require`d or autoloaded for you — wiring the output directory into
  your application's autoload paths is up to you.

## Development

After checking out the repo, run `bin/setup` to install dependencies.

```console
$ bin/rspec         # run the test suite
$ bin/standardrb    # lint
$ bin/srb tc        # type check
$ bin/tapioca gems  # regenerate RBIs for gems
$ bin/console       # interactive prompt
```

`example.yaml` at the repository root is a small microblog API used for trying the generator out.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new
version, update the version number in `version.rb`, and then run `bundle exec rake release`, which
will create a git tag for the version, push git commits and the created tag, and push the `.gem`
file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yantene/openapi-sorbet-rails.
This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere
to the [code of conduct](https://github.com/yantene/openapi-sorbet-rails/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the OpenAPI Sorbet Rails project's codebases, issue trackers, chat rooms and mailing lists is
expected to follow the [code of conduct](https://github.com/yantene/openapi-sorbet-rails/blob/main/CODE_OF_CONDUCT.md).
