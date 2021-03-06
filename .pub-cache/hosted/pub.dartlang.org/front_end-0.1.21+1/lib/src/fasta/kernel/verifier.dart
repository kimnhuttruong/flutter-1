// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.verifier;

import 'package:kernel/ast.dart'
    show
        AsExpression,
        Class,
        Component,
        ExpressionStatement,
        Field,
        Let,
        Library,
        Member,
        Procedure,
        StaticInvocation,
        SuperMethodInvocation,
        SuperPropertyGet,
        SuperPropertySet,
        TreeNode;

import 'package:kernel/transformations/flags.dart' show TransformerFlag;

import 'package:kernel/verifier.dart' show VerifyingVisitor;

import '../compiler_context.dart' show CompilerContext;

import '../fasta_codes.dart'
    show LocatedMessage, noLength, templateInternalProblemVerificationError;

import '../severity.dart' show Severity;

import '../type_inference/type_schema.dart' show TypeSchemaVisitor, UnknownType;

import 'kernel_shadow_ast.dart' show SyntheticExpressionJudgment;

import 'redirecting_factory_body.dart'
    show RedirectingFactoryBody, getRedirectingFactoryBody;

List<LocatedMessage> verifyComponent(Component component,
    {bool isOutline: false, bool skipPlatform: false}) {
  FastaVerifyingVisitor verifier =
      new FastaVerifyingVisitor(isOutline, skipPlatform);
  component.accept(verifier);
  return verifier.errors;
}

class FastaVerifyingVisitor extends VerifyingVisitor
    implements TypeSchemaVisitor<void> {
  final List<LocatedMessage> errors = <LocatedMessage>[];

  Uri fileUri;
  final bool skipPlatform;

  FastaVerifyingVisitor(bool isOutline, this.skipPlatform) {
    this.isOutline = isOutline;
  }

  Uri checkLocation(TreeNode node, String name, Uri fileUri) {
    if (name == null || name.contains("#")) {
      // TODO(ahe): Investigate if these checks can be enabled:
      // if (node.fileUri != null && node is! Library) {
      //   problem(node, "A synthetic node shouldn't have a fileUri",
      //       context: node);
      // }
      // if (node.fileOffset != -1) {
      //   problem(node, "A synthetic node shouldn't have a fileOffset",
      //       context: node);
      // }
      return fileUri;
    } else {
      if (fileUri == null) {
        problem(node, "'$name' has no fileUri", context: node);
        return fileUri;
      }
      if (node.fileOffset == -1 && node is! Library) {
        problem(node, "'$name' has no fileOffset", context: node);
      }
      return fileUri;
    }
  }

  void checkSuperInvocation(TreeNode node) {
    var containingMember = getContainingMember(node);
    if (containingMember == null) {
      problem(node, 'Super call outside of any member');
    } else {
      if (containingMember.transformerFlags & TransformerFlag.superCalls == 0) {
        problem(
            node, 'Super call in a member lacking TransformerFlag.superCalls');
      }
    }
  }

  Member getContainingMember(TreeNode node) {
    while (node != null) {
      if (node is Member) return node;
      node = node.parent;
    }
    return null;
  }

  @override
  problem(TreeNode node, String details, {TreeNode context}) {
    node ??= (context ?? this.context);
    int offset = node?.fileOffset ?? -1;
    Uri file = node?.location?.file ?? fileUri;
    Uri uri = file == null ? null : file;
    LocatedMessage message = templateInternalProblemVerificationError
        .withArguments(details)
        .withLocation(uri, offset, noLength);
    CompilerContext.current.report(message, Severity.error);
    errors.add(message);
  }

  @override
  visitAsExpression(AsExpression node) {
    super.visitAsExpression(node);
    if (node.fileOffset == -1) {
      TreeNode parent = node.parent;
      while (parent != null) {
        if (parent.fileOffset != -1) break;
        parent = parent.parent;
      }
      problem(parent, "No offset for $node", context: node);
    }
  }

  @override
  visitExpressionStatement(ExpressionStatement node) {
    // Bypass verification of the [StaticGet] in [RedirectingFactoryBody] as
    // this is a static get without a getter.
    if (node is! RedirectingFactoryBody) {
      super.visitExpressionStatement(node);
    }
  }

  @override
  visitLet(Let node) {
    if (node is SyntheticExpressionJudgment) {
      problem(node, "Leaking shadow node: ${node.runtimeType}");
    }
    super.visitLet(node);
  }

  @override
  visitLibrary(Library node) {
    // Issue(http://dartbug.com/32530)
    if (skipPlatform && node.importUri.scheme == 'dart') {
      return;
    }
    fileUri = checkLocation(node, node.name, node.fileUri);
    super.visitLibrary(node);
  }

  @override
  visitClass(Class node) {
    fileUri = checkLocation(node, node.name, node.fileUri);
    super.visitClass(node);
  }

  @override
  visitField(Field node) {
    fileUri = checkLocation(node, node.name.name, node.fileUri);
    super.visitField(node);
  }

  @override
  visitProcedure(Procedure node) {
    fileUri = checkLocation(node, node.name.name, node.fileUri);
    super.visitProcedure(node);
  }

  @override
  visitUnknownType(UnknownType node) {
    // Note: we can't pass [node] to [problem] because it's not a [TreeNode].
    problem(null, "Unexpected appearance of the unknown type.");
  }

  @override
  visitSuperMethodInvocation(SuperMethodInvocation node) {
    checkSuperInvocation(node);
    super.visitSuperMethodInvocation(node);
  }

  @override
  visitSuperPropertyGet(SuperPropertyGet node) {
    checkSuperInvocation(node);
    super.visitSuperPropertyGet(node);
  }

  @override
  visitSuperPropertySet(SuperPropertySet node) {
    checkSuperInvocation(node);
    super.visitSuperPropertySet(node);
  }

  @override
  visitStaticInvocation(StaticInvocation node) {
    super.visitStaticInvocation(node);
    RedirectingFactoryBody body = getRedirectingFactoryBody(node.target);
    if (body != null) {
      problem(node, "Attempt to invoke redirecting factory.");
    }
  }
}
