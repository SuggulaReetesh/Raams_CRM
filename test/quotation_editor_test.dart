import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raams_crm/finance.dart';
import 'package:raams_crm/main.dart';

void main() {
  test(
    'square-foot quotation lines calculate and preserve their price basis',
    () {
      const areaLine = StudioQuoteLine(
        id: 'area-line',
        description: 'Wardrobe',
        quantity: 2,
        unit: 'sq ft',
        unitRate: 100,
        packageName: 'Basic',
        catalogItemId: 'wardrobe',
        pricingBasis: 'area_sqft',
        lengthMm: 1000,
        widthMm: 1000,
      );
      expect(areaLine.amount, 215.28);
      expect(
        StudioQuoteLine.fromJson(areaLine.toJson()).amount,
        areaLine.amount,
      );

      const legacyLine = StudioQuoteLine(
        id: 'legacy-line',
        description: 'Existing item',
        quantity: 2,
        unit: 'item',
        unitRate: 100,
        lengthMm: 1000,
        widthMm: 1000,
      );
      expect(legacyLine.amount, 200);
    },
  );

  testWidgets('quotation line items can be added and removed inline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.utc(2026);
    await tester.pumpWidget(
      MaterialApp(
        home: QuotationEditorPage(
          quotation: StudioQuotation(
            id: 'quotation-1',
            number: 'Q-1',
            projectId: 'project-1',
            projectName: 'Kitchen',
            clientId: 'client-1',
            clientName: 'Client',
            clientEmail: '',
            title: 'Kitchen scope',
            items: const [],
            taxRate: 0,
            currencySymbol: '\$',
            createdAt: now,
            updatedAt: now,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Line items (0)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add custom line'));
    await tester.pumpAndSettle();

    expect(find.text('Line items (1)'), findsOneWidget);
    expect(find.byTooltip('Remove line item'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.byTooltip('Remove line item'));
    await tester.pumpAndSettle();

    expect(find.text('Line items (0)'), findsOneWidget);
    expect(find.byTooltip('Remove line item'), findsNothing);
  });

  testWidgets('catalog quick-add uses the configured basic area rate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.utc(2026);
    await tester.pumpWidget(
      MaterialApp(
        home: QuotationEditorPage(
          quotation: StudioQuotation(
            id: 'quotation-2',
            number: 'Q-2',
            projectId: 'project-1',
            projectName: 'Kitchen',
            clientId: 'client-1',
            clientName: 'Client',
            clientEmail: '',
            title: 'Kitchen scope',
            items: const [],
            taxRate: 0,
            currencySymbol: '₹',
            createdAt: now,
            updatedAt: now,
          ),
          catalog: const [
            StudioLineItemCatalogEntry(
              id: 'wardrobe',
              name: 'Wardrobe',
              basicRatePerSqft: 100,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Line items (0)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Wardrobe'));
    await tester.pumpAndSettle();

    final dimensionFields = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'mm',
    );
    expect(dimensionFields, findsNWidgets(2));
    await tester.enterText(dimensionFields.first, '1000');
    await tester.enterText(dimensionFields.last, '1000');
    await tester.pumpAndSettle();

    expect(find.text('Wardrobe'), findsWidgets);
    expect(find.text('₹107.64'), findsOneWidget);
  });
}
