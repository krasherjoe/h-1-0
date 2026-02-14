// Version: 2026-02-15
/**
 * Summary Section Component
 * Migrated from Flutter _buildSummarySection()
 */

import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { TaxDisplayMode } from '../../models';

interface SummarySectionProps {
    subtotal: number;
    tax: number;
    totalAmount: number;
    taxDisplayMode: TaxDisplayMode;
}

export const SummarySection: React.FC<SummarySectionProps> = ({
    subtotal,
    tax,
    totalAmount,
    taxDisplayMode,
}) => {
    const SummaryRow: React.FC<{
        label: string;
        value: string;
        isTotal?: boolean;
    }> = ({ label, value, isTotal = false }) => (
        <View style={styles.row}>
            <Text style={[styles.label, isTotal && styles.totalLabel]}>{label}</Text>
            <Text style={[styles.value, isTotal && styles.totalValue]}>{value}</Text>
        </View>
    );

    return (
        <View style={styles.container}>
            <SummaryRow label="小計" value={`¥${subtotal.toLocaleString()}`} />

            {taxDisplayMode === 'normal' && (
                <SummaryRow label="消費税" value={`¥${tax.toLocaleString()}`} />
            )}

            {taxDisplayMode === 'text_only' && (
                <SummaryRow label="消費税" value="(税抜)" />
            )}

            <View style={styles.separator} />

            <SummaryRow
                label={taxDisplayMode === 'hidden' ? '合計' : '合計（税込）'}
                value={`¥${totalAmount.toLocaleString()}`}
                isTotal
            />
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        padding: 16,
        backgroundColor: '#f5f5f5',
        borderRadius: 8,
        marginBottom: 16,
    },
    row: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        marginBottom: 8,
    },
    label: {
        fontSize: 14,
        color: '#666',
    },
    value: {
        fontSize: 14,
        fontWeight: '600',
        color: '#333',
    },
    totalLabel: {
        fontSize: 18,
        fontWeight: '700',
        color: '#000',
    },
    totalValue: {
        fontSize: 18,
        fontWeight: '700',
        color: '#2196F3',
    },
    separator: {
        height: 1,
        backgroundColor: '#ddd',
        marginVertical: 8,
    },
});
