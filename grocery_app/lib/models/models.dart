// ==================== نموذج المنتج ====================
class Product {
  int? id;
  String name;
  String? barcode;
  String category;
  double buyPrice;
  double sellPrice;
  double quantity;
  double minQuantity;
  String unit;
  int? supplierId;
  String? createdAt;
  String? updatedAt;

  Product({
    this.id,
    required this.name,
    this.barcode,
    this.category = 'عام',
    required this.buyPrice,
    required this.sellPrice,
    this.quantity = 0,
    this.minQuantity = 5,
    this.unit = 'قطعة',
    this.supplierId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => quantity <= minQuantity;
  double get profitMargin => sellPrice > 0 ? ((sellPrice - buyPrice) / sellPrice * 100) : 0;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'barcode': barcode,
    'category': category,
    'buy_price': buyPrice,
    'sell_price': sellPrice,
    'quantity': quantity,
    'min_quantity': minQuantity,
    'unit': unit,
    'supplier_id': supplierId,
  };

  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'],
    name: m['name'],
    barcode: m['barcode'],
    category: m['category'] ?? 'عام',
    buyPrice: (m['buy_price'] as num).toDouble(),
    sellPrice: (m['sell_price'] as num).toDouble(),
    quantity: (m['quantity'] as num).toDouble(),
    minQuantity: (m['min_quantity'] as num? ?? 5).toDouble(),
    unit: m['unit'] ?? 'قطعة',
    supplierId: m['supplier_id'],
    createdAt: m['created_at'],
    updatedAt: m['updated_at'],
  );

  Product copyWith({
    int? id, String? name, String? barcode, String? category,
    double? buyPrice, double? sellPrice, double? quantity,
    double? minQuantity, String? unit, int? supplierId,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    barcode: barcode ?? this.barcode,
    category: category ?? this.category,
    buyPrice: buyPrice ?? this.buyPrice,
    sellPrice: sellPrice ?? this.sellPrice,
    quantity: quantity ?? this.quantity,
    minQuantity: minQuantity ?? this.minQuantity,
    unit: unit ?? this.unit,
    supplierId: supplierId ?? this.supplierId,
  );
}

// ==================== نموذج المورد ====================
class Supplier {
  int? id;
  String name;
  String? phone;
  String? address;
  double balance;
  String? notes;
  String? createdAt;

  Supplier({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.balance = 0,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'balance': balance,
    'notes': notes,
  };

  factory Supplier.fromMap(Map<String, dynamic> m) => Supplier(
    id: m['id'],
    name: m['name'],
    phone: m['phone'],
    address: m['address'],
    balance: (m['balance'] as num? ?? 0).toDouble(),
    notes: m['notes'],
    createdAt: m['created_at'],
  );
}

// ==================== نموذج المبيعة ====================
class Sale {
  int? id;
  double total;
  double discount;
  double paid;
  String paymentMethod;
  String? customerName;
  String? notes;
  int? userId;
  String? userName;
  String? createdAt;

  Sale({
    this.id,
    required this.total,
    this.discount = 0,
    required this.paid,
    this.paymentMethod = 'كاش',
    this.customerName,
    this.notes,
    this.userId,
    this.userName,
    this.createdAt,
  });

  double get remaining => total - paid;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'total': total,
    'discount': discount,
    'paid': paid,
    'payment_method': paymentMethod,
    'customer_name': customerName,
    'notes': notes,
    'user_id': userId,
    'user_name': userName,
  };

  factory Sale.fromMap(Map<String, dynamic> m) => Sale(
    id: m['id'],
    total: (m['total'] as num).toDouble(),
    discount: (m['discount'] as num? ?? 0).toDouble(),
    paid: (m['paid'] as num).toDouble(),
    paymentMethod: m['payment_method'] ?? 'كاش',
    customerName: m['customer_name'],
    notes: m['notes'],
    userId: m['user_id'],
    userName: m['user_name'],
    createdAt: m['created_at'],
  );
}

// ==================== نموذج عنصر المبيعة ====================
class SaleItem {
  int? id;
  int saleId;
  int productId;
  String productName;
  double quantity;
  double sellPrice;
  double buyPrice;

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.sellPrice,
    required this.buyPrice,
  });

  double get total => quantity * sellPrice;
  double get profit => (sellPrice - buyPrice) * quantity;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'sale_id': saleId,
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'sell_price': sellPrice,
    'buy_price': buyPrice,
  };

  factory SaleItem.fromMap(Map<String, dynamic> m) => SaleItem(
    id: m['id'],
    saleId: m['sale_id'],
    productId: m['product_id'],
    productName: m['product_name'],
    quantity: (m['quantity'] as num).toDouble(),
    sellPrice: (m['sell_price'] as num).toDouble(),
    buyPrice: (m['buy_price'] as num).toDouble(),
  );
}

// ==================== نموذج المشترى ====================
class Purchase {
  int? id;
  int? supplierId;
  String? supplierName;
  double total;
  double paid;
  String? notes;
  String? createdAt;

  Purchase({
    this.id,
    this.supplierId,
    this.supplierName,
    required this.total,
    this.paid = 0,
    this.notes,
    this.createdAt,
  });

  double get remaining => total - paid;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'supplier_id': supplierId,
    'supplier_name': supplierName,
    'total': total,
    'paid': paid,
    'notes': notes,
  };

  factory Purchase.fromMap(Map<String, dynamic> m) => Purchase(
    id: m['id'],
    supplierId: m['supplier_id'],
    supplierName: m['supplier_name'],
    total: (m['total'] as num).toDouble(),
    paid: (m['paid'] as num? ?? 0).toDouble(),
    notes: m['notes'],
    createdAt: m['created_at'],
  );
}

// ==================== نموذج عنصر المشترى ====================
class PurchaseItem {
  int? id;
  int purchaseId;
  int productId;
  String productName;
  double quantity;
  double buyPrice;

  PurchaseItem({
    this.id,
    required this.purchaseId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.buyPrice,
  });

  double get total => quantity * buyPrice;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'purchase_id': purchaseId,
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'buy_price': buyPrice,
  };

  factory PurchaseItem.fromMap(Map<String, dynamic> m) => PurchaseItem(
    id: m['id'],
    purchaseId: m['purchase_id'],
    productId: m['product_id'],
    productName: m['product_name'],
    quantity: (m['quantity'] as num).toDouble(),
    buyPrice: (m['buy_price'] as num).toDouble(),
  );
}

// ==================== نموذج المصروف ====================
class Expense {
  int? id;
  String title;
  double amount;
  String category;
  String? notes;
  String? createdAt;

  Expense({
    this.id,
    required this.title,
    required this.amount,
    this.category = 'عام',
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'title': title,
    'amount': amount,
    'category': category,
    'notes': notes,
  };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
    id: m['id'],
    title: m['title'],
    amount: (m['amount'] as num).toDouble(),
    category: m['category'] ?? 'عام',
    notes: m['notes'],
    createdAt: m['created_at'],
  );
}

// ==================== عنصر سلة المشتريات ====================
class CartItem {
  Product product;
  double quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.sellPrice * quantity;
  double get profit => (product.sellPrice - product.buyPrice) * quantity;
}
