import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/model_management/model_lifecycle_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../models/invoice_image_draft.dart';
import '../models/review_route_args.dart';
import '../view_models/invoice_extraction_cubit.dart';

class ProcessingView extends StatelessWidget {
  const ProcessingView({required this.image, super.key});

  final InvoiceImageDraft image;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<InvoiceExtractionCubit, InvoiceExtractionState>(
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () async {
              await context.read<InvoiceExtractionCubit>().cancel();
              if (context.mounted) context.pop();
            },
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          title: Text(l10n.processingTitle),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.softBlue, AppColors.softCyan],
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(21),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        state is InvoiceExtractionManualReview
                            ? l10n.processingManualTitle
                            : state is InvoiceExtractionFailure
                            ? l10n.processingFailureTitle
                            : l10n.processingTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        state is InvoiceExtractionManualReview
                            ? l10n.processingManualBody
                            : state is InvoiceExtractionFailure
                            ? l10n.processingFailureBody
                            : l10n.processingBody,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                _ProcessingStep(
                  number: '01',
                  label: l10n.processingStepOne,
                  state: _stepState(state, 0),
                ),
                _Connector(),
                _ProcessingStep(
                  number: '02',
                  label: l10n.processingStepTwo,
                  state: _stepState(state, 1),
                ),
                _Connector(),
                _ProcessingStep(
                  number: '03',
                  label: l10n.processingStepThree,
                  state: _stepState(state, 2),
                ),
                const Spacer(),
                if (state case InvoiceExtractionReady(:final result))
                  PrimaryButton(
                    label: l10n.showDraft,
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => context.pushReplacement(
                      '/review',
                      extra: ReviewRouteArgs(draft: result.draft),
                    ),
                  )
                else if (state case InvoiceExtractionManualReview(
                  :final result,
                ))
                  Column(
                    children: [
                      PrimaryButton(
                        label: l10n.continueManualReview,
                        icon: Icons.edit_note_rounded,
                        onPressed: () => context.pushReplacement(
                          '/review',
                          extra: ReviewRouteArgs(draft: result.draft),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context
                            .read<InvoiceExtractionCubit>()
                            .extract(image),
                        child: Text(l10n.retry),
                      ),
                    ],
                  )
                else if (state is InvoiceExtractionFailure ||
                    state is InvoiceExtractionCancelled)
                  PrimaryButton(
                    label: l10n.retry,
                    icon: Icons.refresh_rounded,
                    onPressed: () =>
                        context.read<InvoiceExtractionCubit>().extract(image),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.read<InvoiceExtractionCubit>().cancel(),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _StepState _stepState(InvoiceExtractionState state, int index) {
    if (state is InvoiceExtractionReady ||
        state is InvoiceExtractionManualReview) {
      return _StepState.done;
    }
    if (state is! InvoiceExtractionRunning) {
      return index == 0 ? _StepState.active : _StepState.waiting;
    }
    final stage = state.lifecycle.stage;
    final activeIndex = switch (stage) {
      ExtractionStage.checkingCapability || ExtractionStage.loadingOcr => 0,
      ExtractionStage.readingImage => 1,
      _ => 2,
    };
    if (index < activeIndex) return _StepState.done;
    if (index == activeIndex) return _StepState.active;
    return _StepState.waiting;
  }
}

enum _StepState { done, active, waiting }

class _ProcessingStep extends StatelessWidget {
  const _ProcessingStep({
    required this.number,
    required this.label,
    required this.state,
  });

  final String number;
  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final isDone = state == _StepState.done;
    final isActive = state == _StepState.active;
    final color = isDone || isActive ? AppColors.blue : AppColors.muted;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.softMint
                : (isActive ? AppColors.softBlue : Theme.of(context).cardColor),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppColors.blue : Colors.transparent,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: Color(0xFF169C75),
                  )
                : Text(
                    number,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: isActive ? null : color),
          ),
        ),
        if (isActive)
          const SizedBox(
            width: 8,
            child: LinearProgressIndicator(
              minHeight: 4,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: 1,
        height: 22,
        margin: const EdgeInsetsDirectional.only(start: 21),
        color: Theme.of(context).dividerColor,
      ),
    );
  }
}
