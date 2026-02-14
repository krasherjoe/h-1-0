// Version: 2026-02-15
/**
 * Items Section Component
 * Migrated from Flutter _buildItemsSection()
 */

import React from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, ScrollView } from 'react-native';
import { InvoiceItem, createInvoiceItem } from '../../models';

interface ItemsSectionProps {
    items: InvoiceItem[];
    onItemsChange: (items: InvoiceItem[]) => void;
}

export const ItemsSection: React.FC<ItemsSectionProps> = ({
    items,
    onItemsChange,
}) => {
    const addItem = () => {
        onItemsChange([...items, createInvoiceItem()]);
    };

    const updateItem = (index: number, field: keyof InvoiceItem, value: string | number) => {
        const newItems = [...items];
        newItems[index] = { ...newItems[index], [field]: value };

        // Recalculate subtotal
        if (field === 'quantity' || field === 'unitPrice') {
            newItems[index].subtotal =
                newItems[index].quantity * newItems[index].unitPrice;
        }

        onItemsChange(newItems);
    };

    const removeItem = (index: number) => {
        const newItems = items.filter((_, i) => i !== index);
        onItemsChange(newItems);
    };

    return (
        <View style={styles.container}>
            <View style={styles.header}>
                <Text style={styles.title}>明細</Text>
                <TouchableOpacity style={styles.addButton} onPress={addItem}>
                    <Text style={styles.addButtonText}>+ 追加</Text>
                </TouchableOpacity>
            </View>

            <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                <View>
                    {/* Table Header */}
                    <View style={styles.tableRow}>
                        <Text style={styles.headerCell}>品目</Text>
                        <Text style={[styles.headerCell, styles.quantityHeader]}>数量</Text>
                        <Text style={[styles.headerCell, styles.priceHeader]}>単価</Text>
                        <Text style={[styles.headerCell, styles.subtotalHeader]}>小計</Text>
                        <Text style={[styles.headerCell, styles.actionHeader]}>削除</Text>
                    </View>

                    {/* Table Body */}
                    {items.map((item, index) => (
                        <View key={index} style={styles.tableRow}>
                            <TextInput
                                style={styles.descriptionInput}
                                value={item.description}
                                onChangeText={(text) => updateItem(index, 'description', text)}
                                placeholder="品目名"
                            />
                            <TextInput
                                style={styles.quantityInput}
                                value={item.quantity.toString()}
                                onChangeText={(text) =>
                                    updateItem(index, 'quantity', parseFloat(text) || 0)
                                }
                                keyboardType="numeric"
                            />
                            <TextInput
                                style={styles.priceInput}
                                value={item.unitPrice.toString()}
                                onChangeText={(text) =>
                                    updateItem(index, 'unitPrice', parseFloat(text) || 0)
                                }
                                keyboardType="numeric"
                            />
                            <Text style={styles.subtotalText}>¥{item.subtotal.toLocaleString()}</Text>
                            <TouchableOpacity onPress={() => removeItem(index)}>
                                <Text style={styles.deleteButton}>🗑️</Text>
                            </TouchableOpacity>
                        </View>
                    ))}
                </View>
            </ScrollView>
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        padding: 16,
        backgroundColor: '#fff',
        borderRadius: 8,
        marginBottom: 16,
    },
    header: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: 12,
    },
    title: {
        fontSize: 16,
        fontWeight: '600',
        color: '#333',
    },
    addButton: {
        backgroundColor: '#4CAF50',
        paddingHorizontal: 16,
        paddingVertical: 8,
        borderRadius: 4,
    },
    addButtonText: {
        color: '#fff',
        fontWeight: '600',
    },
    tableRow: {
        flexDirection: 'row',
        alignItems: 'center',
        marginBottom: 8,
    },
    headerCell: {
        fontSize: 12,
        fontWeight: '600',
        color: '#666',
        padding: 8,
    },
    quantityHeader: {
        width: 80,
    },
    priceHeader: {
        width: 100,
    },
    subtotalHeader: {
        width: 100,
    },
    actionHeader: {
        width: 50,
    },
    descriptionInput: {
        flex: 1,
        minWidth: 200,
        borderWidth: 1,
        borderColor: '#ddd',
        borderRadius: 4,
        padding: 8,
        marginRight: 8,
    },
    quantityInput: {
        width: 80,
        borderWidth: 1,
        borderColor: '#ddd',
        borderRadius: 4,
        padding: 8,
        marginRight: 8,
        textAlign: 'right',
    },
    priceInput: {
        width: 100,
        borderWidth: 1,
        borderColor: '#ddd',
        borderRadius: 4,
        padding: 8,
        marginRight: 8,
        textAlign: 'right',
    },
    subtotalText: {
        width: 100,
        padding: 8,
        marginRight: 8,
        textAlign: 'right',
        fontWeight: '600',
    },
    deleteButton: {
        fontSize: 20,
        padding: 8,
    },
});
