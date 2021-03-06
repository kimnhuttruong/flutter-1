// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.function_type_builder;

import 'builder.dart' show LibraryBuilder, TypeBuilder, TypeVariableBuilder;

import 'package:kernel/ast.dart'
    show
        DartType,
        DynamicType,
        FunctionType,
        NamedType,
        Supertype,
        TypeParameter,
        TypedefType;

import '../fasta_codes.dart'
    show LocatedMessage, messageSupertypeIsFunction, noLength;

import '../problems.dart' show unsupported;

import '../kernel/kernel_builder.dart'
    show
        FormalParameterBuilder,
        LibraryBuilder,
        TypeBuilder,
        TypeVariableBuilder;

class FunctionTypeBuilder extends TypeBuilder {
  final TypeBuilder returnType;
  final List<TypeVariableBuilder> typeVariables;
  final List<FormalParameterBuilder> formals;

  FunctionTypeBuilder(this.returnType, this.typeVariables, this.formals);

  @override
  String get name => null;

  @override
  String get debugName => "Function";

  @override
  StringBuffer printOn(StringBuffer buffer) {
    if (typeVariables != null) {
      buffer.write("<");
      bool isFirst = true;
      for (TypeVariableBuilder t in typeVariables) {
        if (!isFirst) {
          buffer.write(", ");
        } else {
          isFirst = false;
        }
        buffer.write(t.name);
      }
      buffer.write(">");
    }
    buffer.write("(");
    if (formals != null) {
      bool isFirst = true;
      for (dynamic t in formals) {
        if (!isFirst) {
          buffer.write(", ");
        } else {
          isFirst = false;
        }
        buffer.write(t?.fullNameForErrors);
      }
    }
    buffer.write(") -> ");
    buffer.write(returnType?.fullNameForErrors);
    return buffer;
  }

  FunctionType build(LibraryBuilder library, [TypedefType origin]) {
    DartType builtReturnType =
        returnType?.build(library) ?? const DynamicType();
    List<DartType> positionalParameters = <DartType>[];
    List<NamedType> namedParameters;
    int requiredParameterCount = 0;
    if (formals != null) {
      for (FormalParameterBuilder formal in formals) {
        DartType type = formal.type?.build(library) ?? const DynamicType();
        if (formal.isPositional) {
          positionalParameters.add(type);
          if (formal.isRequired) requiredParameterCount++;
        } else if (formal.isNamed) {
          namedParameters ??= <NamedType>[];
          namedParameters.add(new NamedType(formal.name, type));
        }
      }
      if (namedParameters != null) {
        namedParameters.sort();
      }
    }
    List<TypeParameter> typeParameters;
    if (typeVariables != null) {
      typeParameters = <TypeParameter>[];
      for (TypeVariableBuilder t in typeVariables) {
        typeParameters.add(t.parameter);
      }
    }
    return new FunctionType(positionalParameters, builtReturnType,
        namedParameters: namedParameters ?? const <NamedType>[],
        typeParameters: typeParameters ?? const <TypeParameter>[],
        requiredParameterCount: requiredParameterCount,
        typedefType: origin);
  }

  Supertype buildSupertype(
      LibraryBuilder library, int charOffset, Uri fileUri) {
    library.addProblem(
        messageSupertypeIsFunction, charOffset, noLength, fileUri);
    return null;
  }

  Supertype buildMixedInType(
      LibraryBuilder library, int charOffset, Uri fileUri) {
    return buildSupertype(library, charOffset, fileUri);
  }

  @override
  buildInvalidType(LocatedMessage message, {List<LocatedMessage> context}) {
    return unsupported("buildInvalidType", message.charOffset, message.uri);
  }

  FunctionTypeBuilder clone(List<TypeBuilder> newTypes) {
    List<TypeVariableBuilder> clonedTypeVariables;
    if (typeVariables != null) {
      clonedTypeVariables = new List<TypeVariableBuilder>(typeVariables.length);
      for (int i = 0; i < clonedTypeVariables.length; i++) {
        clonedTypeVariables[i] = typeVariables[i].clone(newTypes);
      }
    }
    List<FormalParameterBuilder> clonedFormals;
    if (formals != null) {
      clonedFormals = new List<FormalParameterBuilder>(formals.length);
      for (int i = 0; i < clonedFormals.length; i++) {
        FormalParameterBuilder formal = formals[i];
        clonedFormals[i] = formal.clone(newTypes);
      }
    }
    FunctionTypeBuilder newType = new FunctionTypeBuilder(
        returnType?.clone(newTypes), clonedTypeVariables, clonedFormals);
    newTypes.add(newType);
    return newType;
  }
}
