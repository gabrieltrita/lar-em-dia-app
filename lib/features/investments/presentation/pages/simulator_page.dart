import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/money_input_formatter.dart';
import 'package:lar_em_dia/core/money/per_share.dart';
import 'package:lar_em_dia/core/money/rates.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/features/investments/domain/simulation.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/investments_disclaimer.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class SimulatorPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.simulatorTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.simulatorIncomeTab),
              Tab(text: l10n.simulatorGrowthTab),
            ],
          ),
        ),
        bottomNavigationBar: InvestmentsDisclaimer(
          text: l10n.simulatorDisclaimer,
        ),
        body: const TabBarView(children: [_IncomeTab(), _GrowthTab()]),
      ),
    );
  }
}

abstract final class _Inputs {
  static const maxYears = 50;

  static int? years(String text) => switch (int.tryParse(text.trim())) {
    final years? when years >= 1 && years <= maxYears => years,
    _ => null,
  };

  static int cents(String text) => Money.parse(text) ?? 0;

  static String? yearsError(AppLocalizations l10n, String? text) =>
      years(text ?? '') == null ? l10n.simulatorInvalidYears : null;

  static String? percentError(
    AppLocalizations l10n,
    String? text, {
    bool optional = false,
  }) {
    final value = text?.trim() ?? '';
    if (optional && value.isEmpty) {
      return null;
    }
    return Rates.parseHundredths(value) == null
        ? l10n.simulatorInvalidPercent
        : null;
  }

  static String? amountError(AppLocalizations l10n, String? text) {
    final value = text?.trim() ?? '';
    return value.isEmpty || Money.parse(value) != null
        ? null
        : l10n.validationAmountRequired;
  }

  static List<String> failure(
    AppLocalizations l10n,
    ApiError error,
    List<(String, String)> fields,
  ) => [
    error.localized(l10n),
    for (final (field, label) in fields)
      if (error.localizedField(l10n, field) case final message?)
        '$label: $message',
  ];

  static Widget moneyField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required AppLocalizations l10n,
  }) => TextFormField(
    key: key,
    controller: controller,
    decoration: InputDecoration(labelText: label, prefixText: r'R$ '),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [MoneyInputFormatter()],
    validator: (text) => amountError(l10n, text),
  );

  static Widget yearsField({
    required TextEditingController controller,
    required AppLocalizations l10n,
    required Key key,
  }) => TextFormField(
    key: key,
    controller: controller,
    decoration: InputDecoration(labelText: l10n.simulatorYears),
    keyboardType: TextInputType.number,
    validator: (text) => yearsError(l10n, text),
  );
}

class _IncomeTab extends StatefulWidget {
  const new();

  @override
  State<_IncomeTab> createState() => _IncomeTabState();
}

class _IncomeTabState extends State<_IncomeTab>
    with AutomaticKeepAliveClientMixin {
  final _form = GlobalKey<FormState>();
  final _ticker = TextEditingController();
  final _yield = TextEditingController();
  final _initial = TextEditingController();
  final _monthly = TextEditingController();
  final _years = TextEditingController(text: '10');
  final _target = TextEditingController();
  bool _reinvest = true;
  String? _localError;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final controller in [
      _ticker,
      _yield,
      _initial,
      _monthly,
      _years,
      _target,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    if (!_form.currentState!.validate()) {
      return;
    }
    final ticker = _ticker.text.trim().toUpperCase();
    final yieldBps = Rates.parseHundredths(_yield.text);
    final initial = _Inputs.cents(_initial.text);
    final monthly = _Inputs.cents(_monthly.text);
    final error = ticker.isEmpty && yieldBps == null
        ? l10n.simulatorNeedSource
        : initial == 0 && monthly == 0
        ? l10n.simulatorNeedAmount
        : null;
    setState(() => _localError = error);
    if (error != null) {
      return;
    }
    unawaited(
      context.read<IncomeSimulatorCubit>().simulate(
        IncomeSimulationInput(
          months: _Inputs.years(_years.text)! * 12,
          initialCents: initial,
          monthlyCents: monthly,
          ticker: ticker.isEmpty ? null : ticker,
          monthlyYieldBps: ticker.isEmpty ? yieldBps : null,
          reinvest: _reinvest,
          targetMonthlyIncomeCents: Money.parse(_target.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<IncomeSimulatorCubit, Submission<IncomeSimulation>>(
      builder: (context, state) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('income_ticker'),
                controller: _ticker,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.simulatorTicker,
                  helperText: l10n.simulatorTickerHint,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('income_yield'),
                controller: _yield,
                decoration: InputDecoration(
                  labelText: l10n.simulatorMonthlyYield,
                  helperText: l10n.simulatorMonthlyYieldHint,
                  suffixText: '%',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (text) =>
                    _Inputs.percentError(l10n, text, optional: true),
              ),
              const SizedBox(height: 16),
              _Inputs.moneyField(
                key: const Key('income_initial'),
                controller: _initial,
                label: l10n.simulatorInitial,
                l10n: l10n,
              ),
              const SizedBox(height: 16),
              _Inputs.moneyField(
                key: const Key('income_monthly'),
                controller: _monthly,
                label: l10n.simulatorMonthly,
                l10n: l10n,
              ),
              const SizedBox(height: 16),
              _Inputs.yearsField(
                key: const Key('income_years'),
                controller: _years,
                l10n: l10n,
              ),
              const SizedBox(height: 16),
              _Inputs.moneyField(
                key: const Key('income_target'),
                controller: _target,
                label: l10n.simulatorTarget,
                l10n: l10n,
              ),
              SwitchListTile(
                key: const Key('income_reinvest'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.simulatorReinvest),
                value: _reinvest,
                onChanged: (value) => setState(() => _reinvest = value),
              ),
              if (_localError case final message?)
                ErrorBanner([message])
              else if (state case SubmissionFailure(:final error))
                ErrorBanner(
                  _Inputs.failure(l10n, error, [
                    ('ticker', l10n.simulatorTicker),
                    ('monthly_yield_bps', l10n.simulatorMonthlyYield),
                    ('months', l10n.simulatorYears),
                  ]),
                ),
              const SizedBox(height: 16),
              SubmitButton(
                label: l10n.simulatorRun,
                busy: state is SubmissionInProgress,
                onPressed: () => _submit(l10n),
              ),
              if (state case SubmissionSuccess(value: final result))
                _IncomeResult(result: result),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncomeResult extends StatelessWidget {
  const new({required this.result});

  final IncomeSimulation result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final last = result.last;
    final target = result.targetMonthlyIncomeCents;
    return Column(
      key: const Key('income_result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        if ((result.priceCents, result.monthlyIncomePerShareE8) case (
          final price?,
          final income?,
        ))
          Text(
            l10n.simulatorPricing(
              Money.format(price),
              PerShare.formatE8(income),
            ),
          ),
        _Figures(
          figures: [
            (l10n.simulatorFinalIncome, last.incomeCents),
            (l10n.simulatorReceived, last.receivedCents),
            (l10n.simulatorContributed, last.contributedCents),
            (l10n.simulatorFinalValue, last.valueCents),
          ],
        ),
        if (last.shares case final shares?) Text(l10n.simulatorShares(shares)),
        if (target != null) ...[
          const SizedBox(height: 8),
          if ((result.sharesForTarget, result.capitalForTargetCents) case (
            final shares?,
            final capital?,
          ))
            Text(
              l10n.simulatorTargetShares(
                Money.format(target),
                shares,
                Money.format(capital),
              ),
            )
          else if (result.capitalForTargetCents case final capital?)
            Text(
              l10n.simulatorTargetCapital(
                Money.format(target),
                Money.format(capital),
              ),
            ),
          Text(switch (result.monthsToTarget) {
            final month? => l10n.simulatorTargetReached(month),
            null => l10n.simulatorTargetNotReached,
          }),
        ],
        const SizedBox(height: 16),
        for (final month in result.months)
          if (month.month % 12 == 0 || month == last)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n.simulatorYearRow((month.month + 11) ~/ 12)),
              subtitle: Text(MoneyText.format(month.valueCents)),
              trailing: MoneyText(month.incomeCents),
            ),
      ],
    );
  }
}

class _GrowthTab extends StatefulWidget {
  const new();

  @override
  State<_GrowthTab> createState() => _GrowthTabState();
}

class _GrowthTabState extends State<_GrowthTab>
    with AutomaticKeepAliveClientMixin {
  final _form = GlobalKey<FormState>();
  final _initial = TextEditingController();
  final _monthly = TextEditingController();
  final _years = TextEditingController(text: '10');
  final _rate = TextEditingController();
  String? _localError;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final controller in [_initial, _monthly, _years, _rate]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    if (!_form.currentState!.validate()) {
      return;
    }
    final initial = _Inputs.cents(_initial.text);
    final monthly = _Inputs.cents(_monthly.text);
    final error = initial == 0 && monthly == 0
        ? l10n.simulatorNeedAmount
        : null;
    setState(() => _localError = error);
    if (error != null) {
      return;
    }
    unawaited(
      context.read<GrowthSimulatorCubit>().simulate(
        GrowthSimulationInput(
          months: _Inputs.years(_years.text)! * 12,
          annualRateBps: Rates.parseHundredths(_rate.text)!,
          initialCents: initial,
          monthlyCents: monthly,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<GrowthSimulatorCubit, Submission<GrowthSimulation>>(
      builder: (context, state) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Inputs.moneyField(
                key: const Key('growth_initial'),
                controller: _initial,
                label: l10n.simulatorInitial,
                l10n: l10n,
              ),
              const SizedBox(height: 16),
              _Inputs.moneyField(
                key: const Key('growth_monthly'),
                controller: _monthly,
                label: l10n.simulatorMonthly,
                l10n: l10n,
              ),
              const SizedBox(height: 16),
              _Inputs.yearsField(
                key: const Key('growth_years'),
                controller: _years,
                l10n: l10n,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('growth_rate'),
                controller: _rate,
                decoration: InputDecoration(
                  labelText: l10n.simulatorAnnualRate,
                  helperText: l10n.simulatorAnnualRateHint,
                  suffixText: '%',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (text) => _Inputs.percentError(l10n, text),
              ),
              if (_localError case final message?) ...[
                const SizedBox(height: 16),
                ErrorBanner([message]),
              ] else if (state case SubmissionFailure(:final error)) ...[
                const SizedBox(height: 16),
                ErrorBanner(
                  _Inputs.failure(l10n, error, [
                    ('annual_rate_bps', l10n.simulatorAnnualRate),
                    ('months', l10n.simulatorYears),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              SubmitButton(
                label: l10n.simulatorRun,
                busy: state is SubmissionInProgress,
                onPressed: () => _submit(l10n),
              ),
              if (state case SubmissionSuccess(value: final result))
                _GrowthResult(result: result),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrowthResult extends StatelessWidget {
  const new({required this.result});

  final GrowthSimulation result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final last = result.last;
    return Column(
      key: const Key('growth_result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          l10n.simulatorMonthlyRate(Rates.percentFromE8(result.monthlyRateE8)),
        ),
        _Figures(
          figures: [
            (l10n.simulatorFinalValue, last.valueCents),
            (l10n.simulatorContributed, last.contributedCents),
            (l10n.simulatorEarnings, last.earningsCents),
          ],
        ),
        const SizedBox(height: 16),
        for (final month in result.months)
          if (month.month % 12 == 0 || month == last)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n.simulatorYearRow((month.month + 11) ~/ 12)),
              subtitle: Text(MoneyText.format(month.contributedCents)),
              trailing: MoneyText(month.valueCents),
            ),
      ],
    );
  }
}

class _Figures extends StatelessWidget {
  const new({required this.figures});

  final List<(String, int)> figures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          for (final (label, cents) in figures)
            SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelMedium),
                  MoneyText(cents, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
