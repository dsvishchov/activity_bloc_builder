import 'package:activity_bloc/activity_bloc.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

class ActivityBlocGenerator {
  const ActivityBlocGenerator({
    required this.definingClass,
    required this.method,
    required this.annotation,
  });

  final ClassElement definingClass;
  final MethodElement method;
  final Activity annotation;

  String get inputTypeName => '${_typePrefix}Input';
  String get stateTypeName => '${_typePrefix}State';
  String get blocTypeName => '${_typePrefix}Bloc';

  String generate() {
    return [
      _inputDefinition,
      _blocDefinition,
    ].join();
  }

  String get _inputDefinition {
    if (!_hasInput) {
      return '';
    }

    final constructorParameters = _namedParameters
      .map((parameter) => '${parameter.isRequired ? 'required ' : ''} this.${parameter.name},')
      .join('\n');
    final fields = _namedParameters
      .map((parameter) => 'final ${parameter.type.getDisplayString()} ${parameter.name};')
      .join('\n');

    return '''
      final class $inputTypeName {
        const $inputTypeName({
          $constructorParameters
        });

        $fields
      }
    ''';
  }

  String get _blocDefinition {
    if (!method.returnType.isDartAsyncFuture || (method.returnType is! InterfaceType)) {
      _throwInvalidReturnTypeError(method);
    }

    final returnType = method.returnType as InterfaceType;
    final posiblyEitherType = returnType.typeArguments.firstOrNull;
    if ((posiblyEitherType?.element?.name != 'Either') || (posiblyEitherType is! InterfaceType)) {
      _throwInvalidReturnTypeError(method);
    }

    final eitherType = posiblyEitherType as InterfaceType;
    if (eitherType.typeArguments.length != 2) {
      _throwInvalidReturnTypeError(method);
    }

    final activityTypes = [
      _hasInput ? inputTypeName : 'void',
      eitherType.typeArguments[1].element?.name,
      eitherType.typeArguments[0].element?.name,
    ];

    final activityParameters = _namedParameters
      .map((parameter) => '${parameter.name}: input.${parameter.name},')
      .join('\n');

    return '''
      typedef $stateTypeName = ActivityState<${activityTypes.join(', ')}>;

      final class $blocTypeName extends ActivityBloc<${activityTypes.join(', ')}> {
        $blocTypeName({
          required this.source,
          ${_hasInput ? 'super.input,' : '// No input'}
          super.output,
          super.runImmediately,
          super.runSilently,
        }) : super(
          activity: (input) => source.${method.name}(
            $activityParameters
          ),
        );

        final ${definingClass.name} source;
      }
    ''';
  }

  String get _name => annotation.name ?? method.name;

  String get _typePrefix => '${_name[0].toUpperCase()}${_name.substring(1)}';

  List<ParameterElement> get _namedParameters =>
    method.parameters.where((parameter) => parameter.isNamed).toList();

  bool get _hasInput => _namedParameters.isNotEmpty;

  void _throwInvalidReturnTypeError(Element element) {
    throw InvalidGenerationSourceError(
      '@activity can only be applied to async methods with return type of Future<Either<F, O>>',
      element: element,
    );
  }
}
