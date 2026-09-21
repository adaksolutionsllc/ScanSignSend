import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/signature_repository.dart';
import '../../../core/utils/path_resolver.dart';
import '../../../core/utils/router.dart';
import '../../../core/utils/l10n_ext.dart';

class SignaturesManagerScreen extends ConsumerWidget {
  const SignaturesManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sigRepo = ref.watch(signatureRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.signaturesTitle)),
      body: StreamBuilder<List<Signature>>(
        stream: sigRepo.watchAll(),
        builder: (context, snapshot) {
          final sigs = snapshot.data ?? [];
          if (sigs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.draw_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(context.l10n.signaturesEmpty),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _addNew(context),
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.signaturesAdd),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: sigs.length,
            itemBuilder: (context, i) {
              final sig = sigs[i];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: SizedBox(
                    width: 80,
                    height: 48,
                    child: File(PathResolver.resolve(sig.imagePath))
                            .existsSync()
                        ? Image.file(File(PathResolver.resolve(sig.imagePath)),
                            fit: BoxFit.contain)
                        : const Icon(Icons.broken_image_outlined),
                  ),
                  title: Text(sig.label),
                  subtitle: sig.isDefault
                      ? Text(context.l10n.signaturesDefaultBadge,
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600))
                      : null,
                  trailing: PopupMenuButton<_SigAction>(
                    onSelected: (action) =>
                        _handleAction(context, ref, sig, action),
                    itemBuilder: (ctx) => [
                      if (!sig.isDefault)
                        PopupMenuItem(
                          value: _SigAction.setDefault,
                          child: Text(context.l10n.signaturesSetDefault),
                        ),
                      PopupMenuItem(
                        value: _SigAction.delete,
                        child: Text(context.l10n.actionDelete),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNew(context),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.signaturesAdd),
      ),
    );
  }

  void _addNew(BuildContext context) {
    // Navigate to signature capture with sentinel docId/fieldId=0
    // The capture screen handles 0 fieldId by saving sig only (no field link)
    context.push(
      AppRoutes.signatureCapture
          .replaceAll(':docId', '0')
          .replaceAll(':fieldId', '0'),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    Signature sig,
    _SigAction action,
  ) async {
    final repo = ref.read(signatureRepositoryProvider);
    switch (action) {
      case _SigAction.setDefault:
        await repo.setDefault(sig.id);
      case _SigAction.delete:
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.signaturesDeleteTitle),
            content: Text(context.l10n.signaturesDeleteBody(sig.label)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.l10n.actionCancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(context.l10n.actionDelete)),
            ],
          ),
        );
        if (confirm == true) {
          await repo.deleteSignature(sig.id);
          // Clean up the image file
          final f = File(PathResolver.resolve(sig.imagePath));
          if (f.existsSync()) await f.delete();
        }
    }
  }
}

enum _SigAction { setDefault, delete }
