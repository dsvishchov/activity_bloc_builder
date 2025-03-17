import 'package:activity_bloc/activity_bloc.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'activity_bloc_generator.dart';

class ActivitiesGenerator extends GeneratorForAnnotation<Activities> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      _throwInvalidTargetError(element);
    }
    final definingClass = element as ClassElement;

    final buffer = StringBuffer();

    final methods = definingClass.methods;
    for (final method in methods) {
      final annotation = _getActivityAnnotation(method);

      if (annotation != null) {
        final blocGenerator = ActivityBlocGenerator(
          definingClass: definingClass,
          method: method,
          annotation: annotation,
        );

        buffer.write(blocGenerator.generate());
      }
    }

    return buffer.toString();
  }


  Activity? _getActivityAnnotation(MethodElement method) {
    final annotation = const TypeChecker
      .fromRuntime(Activity)
      .firstAnnotationOf(method);

    if (annotation == null) {
      return null;
    }

    final reader = ConstantReader(annotation);
    final name = reader.peek('name');

    return Activity(
      name: name?.stringValue ?? method.name,
    );
  }

  void _throwInvalidTargetError(Element element) {
    throw InvalidGenerationSourceError(
      '@activities can only be applied to classes.',
      element: element,
    );
  }
}