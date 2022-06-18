[![Flutter Community: rx_command](https://fluttercommunity.dev/_github/header/rx_command)](https://github.com/fluttercommunity/community)

# RxCommand

> **BREAKING CHANGE with V4.0** All creation functions got renamed to be more descriptive than the numbered ones. The new variants are:
>
```Dart
static RxCommand<TParam, TResult> createSync<TParam, TResult>(Func1<TParam, TResult> func,...
static RxCommand<void, TResult> createSyncNoParam<TResult>(Func<TResult> func,...
static RxCommand<TParam, void> createSyncNoResult<TParam>(Action1<TParam> action,...
static RxCommand<void, void> createSyncNoParamNoResult(Action action,...

static RxCommand<TParam, TResult> createAsync<TParam, TResult>(AsyncFunc1<TParam, TResult> func,...
static RxCommand<void, TResult> createAsyncNoParam<TResult>(AsyncFunc<TResult> func,...
static RxCommand<TParam, void> createAsyncNoResult<TParam>(AsyncAction1<TParam> action,...
static RxCommand<void, void> createAsyncNoParamNoResult(AsyncAction action,...
```


> IMPORTANT: As of V3.0 `CommandResult` objects are now emitted on the `.results` property and the pure results of the wrapped function on the RxCommand itself. So I switched the two because while working on RxVMS it turned out that I use the pure result much more often. Also the name of `.results` matches much better with `CommandResult`. If you don't want to change your code you can just stay on 2.06 if you don't need any of V 3.0 features. 


You can find a tutorial on how to use `RxCommands` in this blog post [Making Flutter more Reactive](https://www.burkharts.net/apps/blog/making-flutter-more-reactive/)

`RxCommand` is an [_Reactive Extensions_ (Rx)](http://reactivex.io/) based abstraction for event handlers. It is based on `ReactiveCommand` for the [ReactiveUI](https://reactiveui.net/) framework. It makes heavy use of the [RxDart](https://github.com/ReactiveX/rxdart) package.

>PRs are always welcome ;-)

> MAYBE BREAKING CHANGE in 2.0.0: Till now the `results` Observable and the `RxCommand` itself behaved like a `BehaviourSubjects`. This can lead to problems when using with Flutter.
From now on the default is `PublishSubject`. If you need `BehaviourSubject` behaviour, meaning every new listener gets the last received value, you can set `emitsLastValueToNewSubscriptions = true` when creating `RxCommand`.

If you don't know Rx think of it as Dart `Streams` on steroids. `RxCommand` capsules a given handler function that can then be executed by its `execute` method or directly assigned to a widget's handler because it's a callable class. The result of this method is then published through its Observable interface (Observable wrap Dart Streams). Additionally it offers Observables for it's current execution state, if the command can be executed and for all possibly thrown exceptions during command execution.

A very simple example

```Dart
final command = RxCommand.createSync<int, String>((myInt) => "$myInt");

command.listen((s) => print(s)); // Setup the listener that now waits for events, not doing anything

// Somwhere else
command.execute(10); // the listener will print "10"
```

Getting a bit more impressive:

```Dart
// This command will be executed everytime the text in a TextField changes
final textChangedCommand = RxCommand.createSync((s) => s);

// handler for results
textChangedCommand
  .debounce( new Duration(milliseconds: 500))  // Rx magic: make sure we start processing 
                                               // only if the user make a short pause typing 
    .listen( (filterText)
    {
      updateWeatherCommand.execute( filterText); // I could omit he execute because RxCommand is a callable class but here it 
                                                  //  makes the intention clearer
    });  

```


## Getting Started

Add to your `pubspec.yaml` dependencies to `rxdart` and `rx_command`.  

An `RxCommand` is a generic class of type `RxCommand<TParam, TRESULT>` where `TPARAM` is the type of data that is passed when calling `execute` and `TResult` denotes the return type of the handler function. To signal that a handler doesn't take a parameter or returns a `null` value use `void` as type. 
Even if you create a `RxCommand<void,void>` you will receive a `null` value when the wrapped function finishes so you can listen for the successful completion.

An example of the declaration from the included sample App

```Dart
RxCommand<String,List<WeatherEntry>>  updateWeatherCommand;
RxCommand<bool,bool>  switchChangedCommand;
```

`updateWeatherCommand` expects a handler that takes a `String` as parameter and returns a `List<WeatherEntry>`. `switchChangedCommand` expects and returns a `bool` value 

### Creating RxCommands

 For the different variations of possible handler methods RxCommand offers several factory methods for synchronous and asynchronous handlers. They look like this.

```Dart
  /// Creates  a RxCommand for a synchronous handler function with no parameter and no return type 
  /// `action`: handler function
  /// `canExecute` : observable that can be used to enable/disable the command based on some other state change
  /// if omitted the command can be executed always except it's already executing
  static RxCommand<void, void> createSyncNoParamNoResult(Action action,[Observable<bool> canExecute])
```

There are these variants:

```Dart
static RxCommand<TParam, TResult> createSync<TParam, TResult>(Func1<TParam, TResult> func,...
static RxCommand<void, TResult> createSyncNoParam<TResult>(Func<TResult> func,...
static RxCommand<TParam, void> createSyncNoResult<TParam>(Action1<TParam> action,...
static RxCommand<void, void> createSyncNoParamNoResult(Action action,...

static RxCommand<TParam, TResult> createAsync<TParam, TResult>(AsyncFunc1<TParam, TResult> func,...
static RxCommand<void, TResult> createAsyncNoParam<TResult>(AsyncFunc<TResult> func,...
static RxCommand<TParam, void> createAsyncNoResult<TParam>(AsyncAction1<TParam> action,...
static RxCommand<void, void> createAsyncNoParamNoResult(AsyncAction action,...
```

Please check the API docs for detailed description of all parameters

#### createFromStream

  Creates  a RxCommand from an "one time" observable. This is handy if used together with a Stream generator function.  
  `provider`: provider function that returns a new `Stream` that will be subscribed on the call of [execute]
  `canExecute` : observable that can be used to enable/disable the command based on some other state change
  If omitted the command can be executed always except it's already executing

```Dart
  static RxCommand<TParam, TResult> createFromStream<TParam, TResult>(StreamProvider<TParam, TResult> provider, [Observable<bool> canExecute])
```

You can pass in an additional `Observable<bool>` as `canExceute` that determines if command can be executed. 

#### Example for `canExceute`

The sample App contains a `Switch` widget that enables/disables the update command. The switch itself is bound to the `switchChangedCommand` that's result is then used as `canExcecute` of the `updateWeatherCommand`:

```Dart
switchChangedCommand = RxCommand.createSync<bool,bool>((b)=>b);

// We pass the result of switchChangedCommand as canExecute Observable to the upDateWeatherCommand
updateWeatherCommand = RxCommand.createAsync<String,List<WeatherEntry>>(update,switchChangedCommand.results);
```

As the _Update_ `Button`'s building is based on a `StreamBuilder`that listens on the `canExecute` Observable of the `updateWeatherCommand` the buttons enabled/disabled state gets automatically updated when the `Switch's` state changes


#### Error handling with RxCommands
By default all exceptions thrown by the wrapped function will be caught and swallowed. If you want to react on the, you can listen on the `thrownException` property.
If you want to force RxCommand not to catch Exceptions set `throwExceptions=true`.


### Using RxCommands in a Flutter App

`RxCommand` is typically used in a ViewModel of a Page, which is made accessible to the Widgets via an `InheritedWidget` or `GetIt`. Its `execute`method can then directly be assigned as event handler of the Widgets.

The `result` of the command is best used with a `StreamBuilder` or inside a `StatefulWidget`.

By subscribing (listening) to the `isExecuting` property of a RxCommand you can react on any execution state change of the command. E.g. show a spinner while the command is running.

By subscribing to the `canExecute` property of a RxCommand you can react on any state change of the executability of the command. Like changing the appearance of a Button.

As RxCommand is a callable class you can assign it directly to handler functions of Flutter widgets like:

```Dart
new TextField(onChanged: TheViewModel.of(context).textChangedCommand,)
```

#### Listening for CommandResults

The original `ReactiveCommand` from _ReactiveUI_ separates the state information of the command into four Observables (`result, thrownExceptions, isExecuting, canExecute`) this works great in an environment that doesn't rebuild the whole screen on state change. Flutter it's often desirable when working with a `StreamBuilder` to have all this information at one place so that you can decide what to display depending on the returned state. Therefore `RxCommand` offer the `.results` Observable emitting `CommandResult`objects:

```Dart
class CommandResult<T>
{
  final T         data;
  final dynamic error;
  final bool      isExecuting;

  const CommandResult(this.data, this.error, this.isExecuting);

  bool get hasData => data != null;
  bool get hasError => error != null;  
}
```

`isExecuting` will issue a `bool` value on each state change. Even if you subscribe to a newly created command it will issue `false`. When listening for `CommandResult` this normally doesn't make sense, so no initial `CommandResult` will be emitted.
If you want to get an initial Result with `data==null, error==null, isExceuting==false` pass
`emitInitialCommandResult=true` when creating a command.

### Accessing the last result

`RxCommand.lastResult` gives you access to the last successful result of the commands execution.

If you want to get the last result included in the `CommandResult` events while executing or in case of and error you can pass `emitInitialCommandResult=true` when creating the command. 

If you want to assign an initialValue to `.lastResult` e.g. if you use it with a `StreamBuilder's` `initialData` you can pass it with the `initialLastResult` parameter when creating the command.


### Disposing subscriptions (listeners)
When subscribing to an Observable with `.listen` you should store the returned `StreamSubscription` and call `.cancel` on it if you want to cancel this subscription to a later point or if the object where the subscription is made is getting destroyed to avoid memory leaks.
`RxCommand` has a `dispose` function that will cancel all active subscriptions on its observables. Calling `dispose`before a command gets out of scope is a good practise.

## Exploring the sample App 

The best way to understand how `RxCommand` is used is to look at the supplied sample app which is a simple app that queries a REST API for weather data.

### The ViewModel

It follow the MVVM design pattern so all business logic is bundled in the `WeatherViewModel` class in `weather_viewmodel.dart`.

It is made accessible to the Widgets by using an [InheritedWidget](https://docs.flutter.io/flutter/widgets/InheritedWidget-class.html) which is defined in main.dart and returns and instance of `WeatherViewModel`when used like `TheViewModel.of(context)`

The view model publishes two commands 

* `updateWeatherCommand` which makes a call to the weather API and filters the result based on a string that is passed to execute. Its result will be bound to a `StreamBuilder`in your View.
* `switchChangedCommand` which will be bound to a `Switch` widget to enable/disable the `updateWeatherCommand.


### The View

`main.dart` creates the ViewModel and places it at the very base of the app`s widget tree.

`homepage.dart` creates a `Column` with a 

* `TextField` where you can enter a filter text which binds to the ViewModels `textChangedCommand`.

* a middle block which can either be a `ListView` (`WeatherListView`) or a busy spinner. It is created by a `StreamBuilder` which listens to <br/> `TheViewModel.of(context).updateWeatherCommand.isExecuting`<br/>
* A row with the Update `Button` and a `Switch` that toggles if an update should be possible or not by binding to `TheViewModel.of(context).switchChangedCommand)`. To change the enabled state of the button the button is build by a `StreamBuilder` that listens to the  `TheViewModel.of(context).updateWeatherCommand.canExecute` 

`listview.dart` implements `WeatherListView` which consists again of a StreamBuilder which updates automatically by listening on `TheViewModel.of(context).updateWeatherCommand.results`


## Making live easier with RxCommandListeners

If you want to react on more than one Observable of one command the listening and freeing of multiple of subscriptions makes the code less readable and you have to be careful not to forget to cancel all of them.

`RxCommandListener` makes this handling much easier. Its constructor takes a command and direct handler functions for the different state changes:

```Dart
class RxCommandListener<TParam, TResult> {
  final RxCommand<TParam, TResult> command;

  // Is called on every emitted value of the command
  final void Function(TResult value) onValue;
  // Is called when isExceuting changes 
  final void Function(bool isBusy) onIsBusyChange;
  // Is called on exceptions in the wrapped command function
  final void Function(dynamic ex) onError;
  // Is called when canExecute changes
  final void Function(bool state) onCanExecuteChange;
  // is called with the vealue of the .results Observable of the command
  final void Function(CommandResult<TResult> result) onResult;

  // to make the handling of busy states even easier these are called on their respective states 
  final void Function() onIsBusy;
  final void Function() onNotBusy;

  // optional you can directly pass in a debounce duration for the values of the command
  final Duration debounceDuration;

RxCommandListener(this.command,{    
  this.onValue,
  this.onIsBusyChange,
  this.onIsBusy,
  this.onNotBusy,
  this.onError,
  this.onCanExecuteChange,
  this.onResult,
  this.debounceDuration,}
)

 void dispose(); 
```  

You don't have to pass all handler functions. they all are optional so you can just pass the ones you need. You only have to `dispose` the `RxCommandListener` in your `dispose` function and it will cancel all internally uses subscriptions.

Let's compare the same code with and without `RxCommandListener` in some real app code. The `selectAndUploadImageCommand` here is used in a chat screen where the user can upload images to the chat. When the command is called an `ImagePicker` dialog is shown and after successful selection of an image the image is uploaded. On completion of the upload the command returns the storage location  of the image so that a new image chat entry can be created.

```Dart
_selectImageCommandSubscription = sl
      .get<ImageManager>()
      .selectAndUploadImageCommand
      .listen((imageLocation) async {
    if (imageLocation == null) return;
    // this calls the execute method of the command
    sl.get<EventManager>().createChatEntryCommand(new ChatEntry(
            event: widget.event,
            isImage: true,
            content: imageLocation.downloadUrl,
          ));
    });
_selectImageIsExecutingSubscription = sl
      .get<ImageManager>()
      .selectAndUploadImageCommand
      .isExecuting
      .listen((busy) {
    if (busy) {
      MySpinner.show(context);
    } else {
      MySpinner.hide();
    }
  });
_selectImageErrorSubscription = sl
      .get<ImageManager>()
      .selectAndUploadImageCommand
      .thrownExceptions
      .listen((ex) => showMessageDialog(context, 'Upload problem',
          "We cannot upload your selected image at the moment. Please check your internet connection"));
```

to

```Dart
selectImageListener = RxCommandListener(
    command: sl.get<ImageManager>().selectAndUploadImageCommand,
    onValue: (imageLocation) async {
      if (imageLocation == null) return;

      sl.get<EventManager>().createChatEntryCommand(new ChatEntry(
            event: widget.event,
            isImage: true,
            content: imageLocation.downloadUrl,
          ));
    },
    onIsBusy: () => MySpinner.show(context),
    onNotBusy: MySpinner.hide,
    onError: (ex) => showMessageDialog(context, 'Upload problem',
        "We cannot upload your selected image at the moment. Please check your internet connection"));
```

As a rule of thumb I would only use an RxCommandListener if I want to listen to more than one observable.






## Mocking RxCommands

When writing UI Tests with Flutter its often better not to work with the real commands in the ViewModel but to use a `MockCommand` to have better control over the data a command receives and emits.

For this the `MockCommand` class is for. It behaves almost like a normal `RxCommand`

It's created by

```Dart
/// Factory constructor that can take an optional observable to control if the command can be executet
factory MockCommand({Observable<bool> canExecute} )
```

You don't pass a handler function because this should be controlled from the outside.
To control the outcome of the Command execution you can inspect these properties:

```Dart
/// the last value that was passed when execute or the command directly was called
TParam lastPassedValueToExecute;

/// Number of times execute or the command directly was called
int executionCount = 0; 
```

To simulate a certain data output after calling the command use:

```Dart
/// to be able to simulate any output of the command when it is called you can here queue the output data for the next exeution call
queueResultsForNextExecuteCall(List<CommandResult<TResult>> values)
```

To execute the command you can either call the command instance directly or call `execute`

```Dart
/// Can either be called directly or by calling the object itself because RxCommands are callable classes
/// Will increase [executionCount] and assign [lastPassedValueToExecute] the value of [param]
/// If you have queued a result with [queueResultsForNextExecuteCall] it will be copies tho the output stream.
/// [isExecuting], [canExceute] and [results] will work as with a real command.  
execute([TParam param])
```

Here an example from the `rx_widgets` example App

```Dart
testWidgets('Tapping update button updates the weather', (tester) async {
  final model = new MockModel(); // using mockito
  final command = new MockCommand<String,List<WeatherEntry>>();
    final widget = new ModelProvider(
                          model: model,
                          child: new MaterialApp(home: new HomePage()),
                      );

  // to make the mocked model use the MockCommand instance. 
  when(model.updateWeatherCommand).thenReturn(command);
  // if your App does not only access the command but also calls
  // it directly you have to register the call too:
  when(model.updateWeatherCommand()).thenAnswer((_)=>command());

  command.queueResultsForNextExecuteCall([CommandResult<List<WeatherEntry>>(
              [WeatherEntry("London", 10.0, 30.0, "sunny", 12)],null, false)]);

  expect(command.results, emitsInOrder([ crm(null, false, false), // default value that will be emited at startup 
                                 crm([WeatherEntry("London", 10.0, 30.0, "sunny", 12)], // data
                                  false, false) ]));

  await tester.pumpWidget(widget); // Build initial State
  await tester.pump(); // Build after Stream delivers value

  await tester.tap(find.byKey(AppKeys.updateButtonEnabled));


});
```    


To verify the changing states of the command e.g. to check if linked UI controls are created or in a certain state use:


```Dart
/// For a more fine grained control to simulate the different states of an `RxCommand`
/// there are these functions
/// [startExecution] will issue a `CommandResult` with
/// data: null
/// error: null
/// isExecuting : true
void startExecution()

/// [endExecutionWithData] will issue a `CommandResult` with
/// data: [data]
/// error: null
/// isExecuting : false
void endExecutionWithData(TResult data)

/// [endExecutionWithData] will issue a `CommandResult` with
/// data: null
/// error: Exeption([message])
/// isExecuting : false
void endExecutionWithError(String message)

/// [endExecutionWithData] will issue a `CommandResult` with
/// data: null
/// error: null
/// isExecuting : false
void endExecutionNoData()
```

Also an example from `rx_widgets`

```Dart
testWidgets('Shows a loading spinner and disables the button while executing 
            and shows the ListView on data arrival', (tester) async {
  final model = new MockModel();
  final command = new MockCommand<String,List<WeatherEntry>>();
  final widget = new ModelProvider(
                        model: model,
                        child: new MaterialApp(home: new HomePage()),
                      );

  // Link MockCommand instance to mocked field in model
  when(model.updateWeatherCommand).thenReturn(command);


  await tester.pumpWidget(widget);// Build initial State
  await tester.pump(); 

  expect(find.byKey(AppKeys.loadingSpinner), findsNothing);
  expect(find.byKey(AppKeys.updateButtonDisabled), findsNothing);
  expect(find.byKey(AppKeys.updateButtonEnabled), findsOneWidget);
  expect(find.byKey(AppKeys.weatherList), findsNothing);
  expect(find.byKey(AppKeys.loaderError), findsNothing);
  expect(find.byKey(AppKeys.loaderPlaceHolder), findsOneWidget);


  command.startExecution();
  await tester.pump(); 
  // because there are two streams involded it seems we have to pump 
  // twice so that both streambuilders can work
  await tester.pump();  

  expect(find.byKey(AppKeys.loadingSpinner), findsOneWidget);
  expect(find.byKey(AppKeys.updateButtonDisabled), findsOneWidget);
  expect(find.byKey(AppKeys.updateButtonEnabled), findsNothing);
  expect(find.byKey(AppKeys.weatherList), findsNothing);
  expect(find.byKey(AppKeys.loaderError), findsNothing);
  expect(find.byKey(AppKeys.loaderPlaceHolder), findsNothing);

  command.endExecutionWithData([new WeatherEntry("London", 10.0, 30.0, "sunny", 12)]);
  await tester.pump(); // Build after Stream delivers value

  expect(find.byKey(AppKeys.loadingSpinner), findsNothing);
  expect(find.byKey(AppKeys.updateButtonDisabled), findsNothing);
  expect(find.byKey(AppKeys.updateButtonEnabled), findsOneWidget);
  expect(find.byKey(AppKeys.weatherList), findsOneWidget);
  expect(find.byKey(AppKeys.loaderError), findsNothing);
  expect(find.byKey(AppKeys.loaderPlaceHolder), findsNothing);
});
```















