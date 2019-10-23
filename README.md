[![Build Status](https://travis.ibm.com/compose/smash_the_state.svg?token=jqswnXsg6LbeRHSEXA1p&branch=master)](https://travis.ibm.com/compose/smash_the_state)

# Smash the State
A useful utility for transforming state that provides step sequencing, middleware, and validation.

Inspired by [Arpeggiate](https://github.com/onyxrev/arpeggiate), an Elixir operation library by [@onyxrev](https://github.com/onyxrev).

# Example

``` ruby
class CreateUserOperation < SmashTheState::Operation
  # the schema defines how state is initialized. state begins life as a light-weight
  # struct with the keys defined below and values type-cast using
  # https://github.com/Azdaroth/active_model_attributes
  schema do
    attribute :email, :string
    attribute :name,  :string
    attribute :age,   :integer
  end

  # if a validate block is provided, a validation step will be inserted at its position in
  # the class relative to the other steps. failing validation will cause the operation to
  # exit, returning the current state
  validate do
    validates_presence_of :name, :email
  end

  # steps are executed in the order in which they are defined when the operation is
  # run. each step is expected to return the new state of the operation, which is handed
  # to the subsequent step
  step :normalize_data do |state|
    state.tap do |state|
      state.email = state.email.downcase
    end
  end

  custom_validation do |state|
    state.errors.add(:email, "no funny bizness") if state.email.end_with? ".biz"
  end

  # this step receives the normalized state from :normalize_data and creates a user,
  # which, because it is returned from the block, becomes the new operation state
  step :create_user do |state|
    User.create(state.as_json)
  end

  # this step receives the created user as its state and sends the user an email
  step :send_email do |user|
    email_job = Email.send(user.email, "hi there!")
    error!(user) if email_job.failed?
    user
  end

  # this error handler is attached to the :send_email step. if `error!`` is called
  # in a step, the error handler attached to the step is executed with the state as its
  # argument. an optional, second error argument may be passed in when error! is called.
  # if an error handler is run, operation execution halts, subsequent steps are not
  # executed, and the return value of the error handler block is returned to the caller
  error :send_email do |user|
    Logger.error "sending an email to #{user.email} failed"
    # do some error handling here
    user
  end
end

```

# Advanced stuff

## Original state

If the state changes from step-to-step, don't I lose track of my original state? What if I change my state to something else but I need to access the original operation input data?

Each step not only receives the state of the previous step, but also a copy of the original, unmolested state object that was formed from the union of the input params and the schema. To access the original state data, access it as the second argument in your step block.

```ruby
class CreateAnalyticsOperation < SmashTheState::Operation
  schema do
    attribute :action, :string
    attribute :request_ip, :string
    attribute :private_note, :string
  end

  step :create_analytics do |state|
    Analytics.create(action: state.action, request_ip: state.request_ip)
  end

  step :send_private_note do |state, original_state|
    # so state is an Analytics instance here. what if we want the original
    # state? 'state' is no longer our schema-generated state object, but that
    # data is available as 'original_state'. we can send our private note while
    # still forwarding along the analytics state to the next step
    PrivateNote.create(body: original_state.private_note)

    # pass the Analytics state down to the next step
    state
  end
end
```

## Dynamic Schemas (built at runtime)

Maybe your operation needs a more flexible schema than a static state class can provide. Maybe you need to base your schema on some other data model that isn't available at the time the class is evaluated. If you need your state class to be evaluated at runtime, you can specify `dynamic_schema` with a block. The raw params hash will be passed in as the initial state. From there you can create whatever state class you desire at runtime. Be careful with this because this can quickly get out of hand. If you find yourself using dynamic schemas frequently, you may actually want distinct operations with static schemas.

```ruby
class BillingStuff < SmashTheState::Operation
  dynamic_schema do |params|
    # let's say we want to base our schema on an external service.
    # we can call the service and build our schema off of the keys it returns
    # let's say it's something like {name: "...", id: "...", is_paid: "..."}
    BillingService.get_billing_things.keys do |key|
      attribute key, :string
    end
  end

  step :do_more_things do |state|
    # ... we receive a state with name, id, and is_paid attributes ...
  end
end
```

## Middleware

You can define middleware classes to which the operation can delegate steps. The middleware class names can be arbitrarily composed by information pulled from the state.

Let's say you have two database types: `WhiskeyDB` and `AbsintheDB`, each of which have different behaviors in the `:create_environment` step. You can delegate those behaviors using middleware.

``` ruby
class WhiskeyDBCreateMiddleware
  def create_environment(state)
    # do whiskey things
  end
end

```

``` ruby
class AbsintheDBCreateMiddleware
  def create_environment(state)
    # do absinthe things
  end
end
```

``` ruby
class CreateDatabase < SmashTheState::Operation
  schema do
    attribute :name, :string
  end

  middleware_class do |state|
    "#{state.name}CreateMiddleware"
  end

  middleware_step :create_environment

  step :more_things do |state_from_middleware_step|
    # ... and so on
  end
end
```

## Inheritance-like Behavior

Smash is a library that generally follows the functional approach and you should focus on using that approach when using it. However, there are times when sprinkling a dash of inheritance into the mix can make your life easier.

When using the inheritance pattern, all validation blocks are evaluated together and are run together as one big validation step. The parent class' schema is copied to the child class. All steps are copied to the child class, but individual steps may be overridden using `override_step`. Overridden steps are run in the same step index in which they were originally defined in the parent sequence.

``` ruby
class CreateOperation < SmashTheState::Operation
  schema do
    attribute :version, :string
    attribute :name,    :string
  end

  validate do
    validates_presence_of :name
  end

  step :download_image do |state|
    GenericImage.download(name)
  end

  step :create do |state|
    Deployment.create(state.to_hash)
  end

  step :set_up_billing do |deployment|
    Billing.charge_for_deployment(deployment)

    deployment
  end
end

class RestoreOperation < CreateOperation
  # we get the parent class' schema for free when we inherit. if you want to extend the
  # schema in child classes, I recommend breaking out your schema into modules

  # the validation of CreateOperation will be evaluated at the same time as this following
  # block. in other words, not only will :name have to be present, but for restoration,
  # the name has to be the name of a known source image
  validate do
    validate :source_image_exists

    def source_image_exists
      unless SourceImage.exist?(name)
        add_error(:name, "is not a restorable image")
      end
    end
  end

  # steps from the parent class are copied over in order. you can override specific steps
  # in the child class

  # ...download_image runs

  override_step :create do |state|
    # we're going to diverge from create by "restoring" an image rather than "creating" an image
    Deployment.restore(state.to_hash)
  end

  # ... set_up_billing runs
end
```

## Representation

Let's say you want to represent the state of the operation, wrapped in a class that defines some `as_*` and `to_*` methods. You can do this with a `represent` step.

``` ruby
class DatabaseRepresenter
  def initialize(state)
    @state = state
  end

  def as_json
    {name: @state.name, foo: "bar"} # and so on
  end

  def as_xml
    XML.dump(@state)
  end
end
```

``` ruby
class CreateDatabaseOperation < SmashTheState::Operation
  schema do
    attribute :name, :string
  end

  # ... steps

  represent DatabaseRepresenter
end
```

``` ruby
> CreateDatabaseOperation.call(name: "AbsintheDB").as_json
=> {name: "AbsintheDB", foo: "bar"}
```

## Policy

[Pundit](https://github.com/elabs/pundit) style policies are supported via a `policy` method. Failing policies raise a `SmashTheState::Operation::NotAuthorized` exception and run at the position in the sequence in which they are defined. Pass `current_user` into your operation alongside your params.

``` ruby
class DatabasePolicy
  attr_reader :current_user, :database

  def initialize(current_user, database)
    @current_user = current_user
    @database = database
  end

  def allowed?
    @current_user.age > 21
  end
end

class CreateDatabaseOperation < SmashTheState::Operation
  schema do
    attribute :type, :string
    # ...
  end

  step :get_database do |state|
    Database.find_by_type(type: state.type)
  end

  # state is now a database and is passed into DatabasePolicy as "database",
  # while current_user is passed in as "current_user"
  policy DatabasePolicy, :allowed?
end
```

```ruby
CreateDatabaseOperation.call(
  current_user: some_user,
  type: "WhiskeyDB"
  # ... and so on
)
```

The `NotAuthorized` exception will also provide the failing policy instance via a `policy_instance` method so that you can reason about what exactly went wrong.

```ruby
begin
  CreateDatabaseOperation.call(
    current_user: some_user,
    type: "WhiskeyDB"
    # ... and so on
  )
rescue SmashTheState::Operation::NotAuthorized => e
  e.policy_instance.current_user == some_user # true
  e.policy_instance.database.is_a? Database   # also true
end
```

## Continuation

Smash the State operations can be chained. To simplify this, you may use the `continues_from` helper, which frontloads an existing operation in front of the operation being defined. It feeds the state result of the first operation into the first step of the second.

``` ruby
class SecondOperation < SmashTheState::Operation
  continues_from FirstOperation

  step :another_step do |state|
    # ... continue to smash the state
  end
end
```

## Nested State Schemas

While it's best to keep things simple, sometimes things are complex. As such, you may nest state schemas like so:

```ruby
class Database::Create < Compose::Operation
  schema do
    attribute :type, :string

    schema :host do
      attribute :name, :string

      schema :resources do
        attribute :ram_units, :integer
        attribute :cpu_units, :integer
      end

      # nest as many layers deep as you like
    end
  end

  step :allocate_cpu do |state|
    # access the nested state for whatever you need...
    host = Host.new(state.host.name)
    host.cpus = CPU.new(state.host.resources.cpu_units)

    host
  end
end
```

Calling `as_json` on a state will recurse through the nesting to produce a nested hash.

## Type Definitions

Smash the State supports re-usable type definitions that can help to DRY up your operation states. In the above nested schema example, we can DRY up the host schema by turning it into a definition:

``` ruby
class HostDefinition < SmashTheState::Operation::Definition
  definition "Host"

  schema do
    attribute :name, :string

    schema :resources do
      attribute :ram_units, :integer
      attribute :cpu_units, :integer
    end
  end
end
```

Which can then be re-used in other schemas:

``` ruby
class Database::Create < Compose::Operation
  schema do
    attribute :type, :string
    schema :host, ref: HostDefinition
  end
end
```

## Dry Runs

Operations support "dry run" execution. That is to say, dry runs should not produce side-effects but produce output that is similar to the output for a regular run. Because dry runs should not produce side-effects, steps that persist changes cannot be executed safely for dry runs.

To get around this, a specific sequence can be defined for use when running dry. The dry run sequence can refer to steps in the normal sequence by name. Alternatively, if the step produces side-effects, an alternate version of the step can be provided that superficially behaves similarly. Steps also may be skipped entirely simply by omission.


``` ruby
class CreateUserOperation < SmashTheState::Operation
  schema do
    attribute :email, :string
    attribute :name,  :string
    attribute :age,   :integer
    attribute :id,    :integer
  end

  step :downcase_email do |state|
    state.name ||= "Unnamed"
    state
  end

  validate do
    validates_presence_of :email
  end

  # because this step creates a resource, it produces side-effects and is not
  # safe for a dry run
  step :create do |state|
    result = SomeServer.post("/users")
    state.id = result.id
    state
  end

  step :add_phd do |state|
    state.name = state.name + " Ph.D"
    state
  end

  dry_run_sequence do
    step :downcase_email

    # this alternative implementation will instead be executed when run dry,
    # allowing the rest of the operation to function as if the :create step had run
    step :create do |state|
      state.id = (Random.rand * 1000).ceil
      state
    end

    step :add_phd
  end
end
```

``` ruby
> result = CreateUserOperation.dry_run(email: "jack@sparrow.com", age: 31)
> result.errors.empty?
=> true
> result.name
=> "Unnamed Ph.D"
> result.id
=> 145
```

``` ruby
> result = CreateUserOperation.dry_run(name: "Sam", age: 31)
> result.errors.empty?
=> false
> result.errors["email"]
=> ["can't be blank"]
> result.id
=> nil
```

## Specs

Some helpful RSpec helpers are provided.

``` ruby
# spec_helper.rb
require 'smash_the_state/matchers'
```

``` ruby
# continues_from
expect(ContinuingOperation).to continue_from PreludeOperation

# represent
expect(RepresentingOperation).to represent_with SomeRepresenter
expect(RepresentingOperation).to represent_collection_with SomeRepresenter
```
